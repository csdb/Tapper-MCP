 use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Controller
{
        use Artemis::MCP::Scheduler::TestRequest;
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
                #$self->fill_merged_queue();
        }

        method fill_merged_queue()
        {
                my $count_missing_jobs = $self->merged_queue->wanted_length - $self->merged_queue->length;

                # fill up to wanted merged_queue length
                for (1 .. $count_missing_jobs)
                {
                        my $queue = $self->algorithm->get_next_queue();
                        my $testrun_rs = $queue->queued_testruns;
                        my $job   = $testrun_rs->first;
                        $self->merged_queue->add($job) if $job;
                }
        }

        # TODO: wenn fits() nichts liefert       --> wanted_length++, damit potentielle neue Kandidaten reinkommen
        # TODO: beim Rausnehmem aus merged_queue --> wanted_length--, nur, wenn nicht kleiner als count_queues
        #                                                             my $count_queues       = scalar @{$self->algorithm->queues};
        #                                                             $self->merged_queue->wanted_length ($count_queues) if $self->merged_queue->wanted_length <= $count_queues;

        method adapt_merged_queue_length(Any $job) {
                if (not $job) {
                        # increase merged_queue length if no job found
                        $self->merged_queue->wanted_length( $self->merged_queue->wanted_length + 1 );
                } else {
                        # count down merged_queue again on success, but not smaller that count queues
                        $self->merged_queue->wanted_length( $self->merged_queue->wanted_length - 1 )
                            if $self->merged_queue->wanted_length > $self->algorithm->queue_count;
                }
        }

        method get_next_job(ArrayRef $free_hosts, %args) {
                my ($queue, $job);

                my $cur_count_queues = scalar @{$self->algorithm->queues};

                do {
                        use Data::Dumper;

                        $self->fill_merged_queue;
                        $job = $self->merged_queue->get_first_fitting($free_hosts);
                        $self->adapt_merged_queue_length($job);

                } while (not $job and $args{try_until_found});

                # TODO: reduce merged_queue length because we increase it when nothing is found to
                # prevent high priority jobs with tight host requirements to block up the merged queue
                #
                # $self->merged_queue_length($self->merged_queue_length - 1);
                # $self->merged_queue_length ($cur_count_queues)
                #    if $self->merged_queue_length <= $cur_count_queues;

                return $job;    # MCP maintains list of free hosts
        }

        method mark_job_as_running ($job) {
                $job->mark_as_running;
        }

        method mark_job_as_finished ($job) {
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
