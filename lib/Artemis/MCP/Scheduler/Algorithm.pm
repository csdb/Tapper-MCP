use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Algorithm with MooseX::Traits {

        use aliased 'Artemis::MCP::Scheduler::Queue';

        has queues => (
                       is         => 'rw',
                       isa        => 'HashRef['.Queue.']',
                       default    => sub { {} },
                      );

        method add_queue(Artemis::MCP::Scheduler::Queue $q)
        {
                my $qname = $q->name;
                if ($self->queues->{$qname}) {
                        warn "Queue with name '$qname' already exists";
                        return;
                }

                foreach (keys %{$self->queues})
                {
                        $self->queues->{$_}->runcount( 0 );
                }

                $self->queues->{$qname} = $q;
        }

        method remove_client(Artemis::MCP::Scheduler::Queue $q) {
                delete $self->queues->{$q->name};
        }

        method update_client(Artemis::MCP::Scheduler::Queue $q) {
                $q->{runcount} += 1;
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

