use MooseX::Declare;

use 5.010;

## no critic (RequireUseStrict)
class Artemis::MCP::Scheduler::Algorithm with MooseX::Traits {

        use Artemis::Model 'model';

        has queues => (
                       is         => 'rw',
                       isa        => 'HashRef',
                       default    => sub { model('TestrunDB')->resultset('Queue')->official_queuelist },
                      );

        method queue_count { scalar keys %{$self->queues} }

        method add_queue( $q) # Queue
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

        method remove_queue( $q) { # Queue
                delete $self->queues->{$q->name};
        }

        method update_queue( $q) { # Queue
                # interface
                die "Interface update_queue not implemented";
        }

        method lookup_next_queue() {
                # interface
                die "Interface lookup_next_queue not implemented";
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

