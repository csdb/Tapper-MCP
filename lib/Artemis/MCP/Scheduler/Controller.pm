 use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Controller
{
        with 'MooseX::Log::Log4perl';
        use Perl6::Junction qw/ any /;
        use Artemis::Model 'model';
        use aliased 'Artemis::MCP::Scheduler::Algorithm';
        use aliased 'Artemis::MCP::Scheduler::PrioQueue';
        use Artemis::MCP::Net;

        has hostlist  => (is => 'rw', isa => 'ArrayRef');
        has prioqueue => (is => 'rw', isa => PrioQueue, default => sub { PrioQueue->new });
        has algorithm => (is => 'rw',
                          isa => 'Artemis::MCP::Scheduler::Algorithm',
                          default => sub {
                                          Algorithm->new_with_traits
                                          (
                                           traits => ['Artemis::MCP::Scheduler::Algorithm::WFQ']
                                          );
                                         }
                         );


        method get_next_job(Any %args) {
                my ($queue, $job);

                do {{

                        my $free_hosts = Artemis::Model::free_hosts_with_features();
                        return if not ($free_hosts and @$free_hosts);
                        
                        my %queues;
                        my $queue_rs = model('TestrunDB')->resultset('Queue');
                        %queues = map {$_->name, $_} $queue_rs->all;

                QUEUE:
                        while (1) {
                                # ask prioqueue everytime when in loop because new priority jobs
                                # that got into DB between to loop runs still have highest priority
                                last QUEUE if $job = $self->prioqueue->get_first_fitting($free_hosts);
                                
                                
                                my $queue = $self->algorithm->lookup_next_queue(\%queues);
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
                                        $self->algorithm->update_queue($job->queue);
                                        last QUEUE;
                                } else {
                                        delete $queues{$queue->name};
                                }
                                last QUEUE if not %queues;
                        }
                        
                        my $error;
                        eval{
                                 $error=$job->produce_preconditions() if $job;
                         };
                        if ($error or $@) {
                                $error //=$@;
                                my $net    = Artemis::MCP::Net->new();
                                $net->tap_report_send($job->testrun_id, [{error => 1, msg => $error}]);
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
        package Artemis::MCP::Scheduler::Controller;
        our $VERSION = '0.01';
}


=head1 NAME

Artemis::MCP::Scheduler::Controller - Main class of the scheduler

=head1 SYNOPSIS

=head1 FUNCTIONS

# DEACTIVATED
# =head2 get_prioritiy_job

# Check priority queue for a new job and return it.

# @return    job available - ad hoc queue object
# @return no job available - 0

=head2 get_next_job

Pick a testrequest and prepare it for execution. Returns 0 if not testrequest
fits any of the free hosts.

@param ArrayRef - array of host objects associated to hosts with no current test

@return success   - job object
@return no job    - 0

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-wfq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WFQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Artemis::MCP::Scheduler::Controller
