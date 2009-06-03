use MooseX::Declare;

class Artemis::MCP::Scheduler::Queue {

        has name     => (is => 'rw', default => '');
        has producer => (is => 'rw');
        has share    => (is => 'rw', isa => 'Num');

        has object   => (is => 'rw'); # not in Algorithm, but in MCP-Scheduler
        has runcount => (is => 'rw', default => 0); # WFQ specific

=head2 produce

Call the producer method associated with this object.

@param string - hostname

@return success - test run id
@return error   - exception

=cut

        method produce(Str $hostname) {
                die Artemis::Exception::Param("Client ".$self->name."does not have an associated producer")
                    if not $self->producer ;
                return $self->producer->produce($hostname);
        }

}
