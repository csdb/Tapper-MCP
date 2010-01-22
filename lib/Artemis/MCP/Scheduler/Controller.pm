 use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Controller
{
        use Perl6::Junction qw/ any /;
        use Artemis::Model 'model';
        use aliased 'Artemis::MCP::Scheduler::Algorithm';
        use aliased 'Artemis::MCP::Scheduler::MergedQueue';

        has hostlist  => (is => 'rw', isa => 'ArrayRef');
        has algorithm => (is => 'rw',
                          isa => 'Artemis::MCP::Scheduler::Algorithm',
                          default => sub {
                                          Algorithm->new_with_traits
                                          (
                                           traits => ['Artemis::MCP::Scheduler::Algorithm::WFQ']
                                          );
                                         }
                         );
        has merged_queue => (is => 'rw', isa => MergedQueue, default => sub { MergedQueue->new });

        method BUILD {
                $self->merged_queue->wanted_length( $self->algorithm->queue_count );
        }

        method fill_merged_queue()
        {
                my $count_missing_jobs = $self->merged_queue->wanted_length - $self->merged_queue->length;
                my %queues;
                my $queue_rs = model('TestrunDB')->resultset('Queue');
                foreach my $queue_name( map {$_->name} $queue_rs->all ) {
                        $queues{$queue_name} = 1;
                }

                # fill up to wanted merged_queue length, only accept shorter merged_queue if no queue has jobs to offer
                while($count_missing_jobs > 0)
                {
                        my $queue;
                        do {
                                $queue = $self->algorithm->get_next_queue();
                        } while ($queue and not $queue->active);
                        my $testrun_rs = $queue->queued_testruns;
                        my $job   = $testrun_rs->first;
                        if ($job) {
                                $count_missing_jobs--;
                                $self->merged_queue->add($job);
                        } else {
                                delete $queues{$queue->name};
                        }
                        last if not %queues;
                }
        }

        method adapt_merged_queue_length(Any $job, ArrayRef $free_hosts) {
                if (not $job) {
                        # increase merged_queue length if no job found,
                        if ($self->merged_queue->wanted_length - $self->merged_queue->length < 1) # not longer than current length + 1
                        {
                                my $lookup_queue = $self->algorithm->lookup_next_queue();
                                my $queuehosts   = $lookup_queue->queuehosts;

                                if ( grep {$_->{host}->queuehosts->count == 0 } @$free_hosts   ) { # increase if at least one host is free for all queues
                                        $self->merged_queue->wanted_length( $self->merged_queue->wanted_length + 1 );

                                } elsif ($queuehosts->count) {                                     # increase if at least one host is bound to next queue
                                        my @queuehosts = map {$_->host->name}         $queuehosts->all;
                                        my @free_hosts = map {$_->{host}->name} @$free_hosts;
                                        if (any(@queuehosts) eq any(@free_hosts)) {
                                                $self->merged_queue->wanted_length( $self->merged_queue->wanted_length + 1 );
                                        }
                                } else {
                                        $self->algorithm->get_next_queue;
                                }
                        }
                } else {
                        # count down merged_queue again on success,
                        # but not smaller that count queues
                        $self->merged_queue->wanted_length( $self->merged_queue->wanted_length - 1 )
                            if $self->merged_queue->wanted_length > $self->algorithm->queue_count;
                }
        }

        method overfill_merged_queue()
        {
                my $queue_rs = model('TestrunDB')->resultset('Queue');
                my %queues;
                foreach my $queue( $queue_rs->all ) {
                        $queues{$queue->name} = $queue;
                }

                my $jobs = $self->merged_queue->get_testrequests;
                foreach my $tr( $jobs->all() ) {
                        delete($queues{$tr->queue->name}) if defined $queues{$tr->queue->name};
                }

                foreach my $queue_name (keys %queues) {
                        my $queue      = $queues{$queue_name};
                        my $testrun_rs = $queue->queued_testruns;
                        my $job        = $testrun_rs->first;
                        $self->merged_queue->add($job) if $job;
                }
        }


        method get_next_job(Any %args) {
                my ($queue, $job);

                do {{

                        $self->fill_merged_queue;
                        my $free_hosts = Artemis::Model::free_hosts_with_features();
                        return if not ($free_hosts and @$free_hosts);
                        $job = $self->merged_queue->get_first_fitting($free_hosts);
                        $self->overfill_merged_queue() if not $job;
                        my $error=$job->produce_preconditions() if $job;
                        if ($error) {
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
