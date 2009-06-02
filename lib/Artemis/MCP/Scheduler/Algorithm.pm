use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Algorithm {

        use Artemis::MCP::Scheduler::Queue;
        use Data::Dumper;

        has queues => (
                       is         => 'rw',
                       isa        => 'ArrayRef',
                       default    => sub {[]},
                       #auto_deref => 1,
                      );

        #
        method add_queue(Artemis::MCP::Scheduler::Queue $queue) {
                say STDERR "queues: ", Dumper($self->queues);
                $_->runcount( 0 ) foreach @{$self->queues || []};
        }

        #
        method remove_client(Artemis::MCP::Scheduler::Queue $queue) {
                my @new_queues = grep { $_->name ne $queue->name } @{$self->queues || []};
                $self->queues(\@new_queues);
        }

        method update_client(Artemis::MCP::Scheduler::Queue $queue) {
                $queue->{runcount} += 1;
        }

}

=head2 add_client

Add a new client to the scheduler.

@param Scheduler::Client - name of the client has to be unique
@param int               - proportional share

@return success - 0
@return error   - error string


=head2 remove_client

Remove a client from scheduling

@param string - name of the client to be removed

@return success - 0
@return error   - error string


=head2 update_client

Update the time entry of the given client

@param string - name of the client

@return success - 0

=cut

