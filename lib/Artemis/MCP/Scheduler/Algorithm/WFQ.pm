use MooseX::Declare;

use 5.010;

role Artemis::MCP::Scheduler::Algorithm::WFQ
{
        requires 'queues';

        use Artemis::Exception;
        use Artemis::MCP::Scheduler::Queue;
        use TryCatch;
        use Data::Dumper;

=head1 NAME

  WFQ - Scheduling algorithm "Weighted Fair Queueing"

=head1 VERSION

Version 0.01

=cut


=head1 SYNOPSIS

Implements a test for weighted fair queueing scheduling algorithm.


=head1 FUNCTIONS

=cut

=head2 get_virtual_finishing_time

Return the virtual finishing time of a given client

@param string - client

@return success - virtual time
@return error   - error string

=cut

        method get_virtual_finishing_time(Artemis::MCP::Scheduler::Queue $queue) {
                return ($queue->{runcount} + 1.0) / $queue->{share};
        }

=head2 get_next_queue

Evaluate which client has to be scheduled next.

@return success - client name;

=cut

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
                        if (not defined $vft) {
                                $vft   = $this_vft;
                                $queue = $q;
                        } else {
                                if ($vft > $this_vft) {
                                        $vft   = $this_vft;
                                        $queue = $q;
                                }
                        }
                }
                $self->update_client($queue);
                return $queue;
        }
}

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: proprietary


=cut

1; # End of Artemis::MCP::Scheduler::Algorithm::WFQ
