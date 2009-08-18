use MooseX::Declare;

use 5.010;


class Artemis::MCP::Scheduler::Algorithm with MooseX::Traits {

        use aliased 'Artemis::MCP::Scheduler::Queue';

        has queues => (
                       is         => 'rw',
                       isa        => 'HashRef['.Queue.']',
                       default    => sub { {} },
                      );

        method add_queue(Queue $q)
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

        method remove_queue(Queue $q) {
                delete $self->queues->{$q->name};
        }

        method update_queue(Queue $q) {
                # interface
                die "Interface update_queue not implemented";
        }

        method get_next_queue() {
                # interface
                die "Interface get_next_queue not implemented";
        }
}

__END__

=head2 add_queue

Add a new queue to the scheduler.

@param Scheduler::Queue - name of the queue has to be unique

@return success - 0
@return error   - error string


=head2 remove_queue

Remove a queue from scheduling

@param string - name of the queue to be removed

@return success - 0
@return error   - error string


=head2 update_queue

Update the time entry of the given queue

@param string - name of the queue

@return success - 0

=cut

