use MooseX::Declare;

use 5.010;

## no critic (RequireUseStrict)
class Tapper::MCP::Scheduler::Controller extends Tapper::Base with Tapper::MCP::Net::TAP {
        use Tapper::Model 'model';
        use aliased 'Tapper::MCP::Scheduler::Algorithm';
        use aliased 'Tapper::MCP::Scheduler::PrioQueue';
        use Tapper::MCP::Net;

        has hostlist  => (is => 'rw', isa => 'ArrayRef');
        has prioqueue => (is => 'rw', isa => PrioQueue, default => sub { PrioQueue->new });
        has algorithm => (is => 'rw',
                          isa => 'Tapper::MCP::Scheduler::Algorithm',
                          default => sub {
                                          Algorithm->new_with_traits
                                          (
                                           traits => ['Tapper::MCP::Scheduler::Algorithm::WFQ']
                                          );
                                         }
                         );

        has testrun   => (is => 'rw');
        has cfg       => (is => 'ro', default => sub {{}});


=head2

Check whether we need to change from scheduling white bandwidth to black bandwidth.

@return black - 1
@return white - 0

=cut

        method toggle_bandwith_color($free_hosts, $queue)
        {
                return 0 if $queue->queued_testruns->count == 0;
                foreach my $free_host( map {$_->{host} } @$free_hosts) {
                        if ($free_host->queuehosts->count){
                                QUEUE_CHECK:
                                {
                                        foreach my $queuehost($free_host->queuehosts->all) {
                                                return 0 if $queuehost->queue->id == $queue->id;
                                        }
                                }
                        } else {
                                return 0;
                        }
                }
                return 1;
        }


=head2 get_next_job

Pick a testrequest and prepare it for execution. Returns 0 if not testrequest
fits any of the free hosts.

@param ArrayRef - array of host objects associated to hosts with no current test

@return success   - job object
@return no job    - 0

=cut 

        method get_next_job(Any %args) {
                my ($queue, $job);

                do {{

                        my $free_hosts = Tapper::Model::free_hosts_with_features();
                        return if not ($free_hosts and @$free_hosts);


                        my $queues = model('TestrunDB')->resultset('Queue')->official_queuelist();

                        my $white_bandwith=1;  # chosen queue was first choice

                QUEUE:
                        while (1) {
                                # ask prioqueue everytime when in loop because new priority jobs
                                # that got into DB between to loop runs still have highest priority
                                last QUEUE if $job = $self->prioqueue->get_first_fitting($free_hosts);


                                my $queue = $self->algorithm->lookup_next_queue($queues);
                                return () unless $queue;
                                if ($job = $queue->get_first_fitting($free_hosts)) {
                                        if ($job->auto_rerun) {
                                                $job->testrun->rerun;
                                        }
                                        if ($job->testrun->scenario_element) {
                                        ELEMENT:
                                                foreach my $element ($job->testrun->scenario_element->peer_elements) {
                                                        my $peer_job = $element->testrun->testrun_scheduling;
                                                        next ELEMENT if $peer_job->id == $job->id;
                                                        $self->prioqueue->add($peer_job);
                                                }
                                        }
                                        $self->algorithm->update_queue($job->queue) if $white_bandwith;
                                        last QUEUE;
                                } else {
                                        delete $queues->{$queue->name};
                                        $white_bandwith=0 if $self->toggle_bandwith_color($free_hosts, $queue);

                                }
                                last QUEUE if not %$queues;
                        }

                        my $error;
                        eval{
                                 $error=$job->produce_preconditions() if $job;
                         };
                        if ($error or $@) {
                                $error //=$@;
                                $self->testrun($job->testrun);
                                $self->tap_report_send([{error => 1, msg => $error}], $self->mcp_headerlines());
                                $self->mark_job_as_finished($job);
                                return;
                        }
                        if ($job and $job->testrun->scenario_element) {
                                $self->mark_job_as_running($job);
                                if ($job->testrun->scenario_element->peers_need_fitting > 0) {
                                        # do not return this job already
                                        $job = undef;
                                        next;
                                } else {
                                        return map{$_->testrun->testrun_scheduling} $job->testrun->scenario_element->peer_elements->all;
                                }
                        }
                }} while (not $job and $args{try_until_found});

                return $job || () ;
        }

        method mark_job_as_running ($job) {
                $job->testrun->starttime_testrun(model('TestrunDB')->storage->datetime_parser->format_datetime(DateTime->now));
                $job->testrun->update();
                $job->mark_as_running;
        }

        method mark_job_as_finished ($job) {
                $job->testrun->endtime_test_program(model('TestrunDB')->storage->datetime_parser->format_datetime(DateTime->now));
                $job->testrun->update();
                $job->mark_as_finished;
        }

}

{
        # help the CPAN indexer
        package Tapper::MCP::Scheduler::Controller;
}


=head1 NAME

Tapper::MCP::Scheduler::Controller - Main class of the scheduler

=head1 SYNOPSIS

=head1 FUNCTIONS


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-wfq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WFQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd

=cut

1; # End of Tapper::MCP::Scheduler::Controller
