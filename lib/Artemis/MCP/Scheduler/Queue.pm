#use MooseX::Declare;

use 5.010;
use strict;
use warnings;

#class Artemis::MCP::Scheduler::Queue extends Artemis::Schema::TestrunDB::Result::Queue

package Artemis::MCP::Scheduler::Queue;

use parent 'Artemis::Schema::TestrunDB::Result::Queue';

#{

        sub producer
        {
                my ($self) = @_;

                my $producer_class = "Artemis::MCP::Scheduler::PreconditionProducer::".$self->producer;
                eval "use $producer_class";
                return $producer_class->new unless $@;
                return undef;
        }

        sub produce
        {
                my ($self, $request) = @_; # TestRequest

                if (not $self->producer) {
                        warn "Queue ".$self->name." does not have an associated producer";
                } else {
                        print STDERR "Queue.produce/producer: ", Dumper($self->producer);
                        return $self->producer->produce($request)
                }
        }
# }

# {
#         # just for CPAN
#         package Artemis::MCP::Scheduler::Queue;
#         our $VERSION = '0.01';
# }

        1;
        
