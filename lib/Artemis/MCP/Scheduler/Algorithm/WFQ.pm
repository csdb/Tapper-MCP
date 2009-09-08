use MooseX::Declare;

use 5.010;

role Artemis::MCP::Scheduler::Algorithm::WFQ
{
        requires 'queues';

        use aliased 'Artemis::Schema::TestrunDB::Result::Queue';
        use TryCatch;
        use Data::Dumper;

        method get_virtual_finishing_time($queue) # Queue
        {
                return ($queue->runcount + 1.0) / $queue->priority;
        }


        method get_next_queue()
        {
                my $vft;
                my $queue;

                foreach (keys %{$self->queues})
                {
                        my $q = $self->queues->{$_};
                        my $this_vft;

                        try {
                             $this_vft = $self->get_virtual_finishing_time($q);
                            }
                            catch($e) {
                                    die ($e->msg," at ", $e->line,"\n");
                            }
                        if (not defined $vft)
                        {
                                $vft   = $this_vft;
                                $queue = $q;
                        }
                        elsif ($vft > $this_vft)
                        {
                                $vft   = $this_vft;
                                $queue = $q;
                        }
                }
                $self->update_queue($queue);
                return $queue;
        }

        method update_queue( $q) { # Queue
                $q->runcount ( $q->runcount + 1 );
                $q->update;
        }
}

1;

__END__

=head1 NAME

WFQ - Scheduling algorithm "Weighted Fair Queueing"

=head1 SYNOPSIS

Implements a test for weighted fair queueing scheduling algorithm.


=head1 FUNCTIONS

=head2 get_virtual_finishing_time

Return the virtual finishing time of a given client

@param string - client

@return success - virtual time
@return error   - error string

head2 get_next_queue

Evaluate which client has to be scheduled next.

@return success - client name;

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: proprietary


