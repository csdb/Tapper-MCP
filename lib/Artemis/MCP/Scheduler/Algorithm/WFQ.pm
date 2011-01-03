use MooseX::Declare;

use 5.010;

## no critic (RequireUseStrict)
role Artemis::MCP::Scheduler::Algorithm::WFQ
{
        requires 'queues';

#        use aliased 'Artemis::Schema::TestrunDB::Result::Queue';

        method get_virtual_finishing_time($queue) # Queue
        {
                my $prio = $queue->priority || 1;
                return ($queue->runcount + 1.0) / $prio;
        }


        method lookup_next_queue($queues)
        {
                my $vft;
                my $queue;

                foreach my $q (values %$queues)
                {
                        my $this_vft;
                        next if not $q->priority;

                        $this_vft = $self->get_virtual_finishing_time($q);

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
                return $queue;
        }



        method get_next_queue()
        {
                my $vft;
                my $queue = $self->lookup_next_queue($self->queues);
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

Artemis::MCP::Scheduler::Algorithm::WFQ - Scheduling algorithm "Weighted Fair Queueing"

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


