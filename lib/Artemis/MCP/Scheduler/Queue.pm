#use MooseX::Declare;

use 5.010;
use strict;
use warnings;

class Artemis::MCP::Scheduler::Queue {
        extends 'Artemis::Schema::TestrunDB::Result::Queue';
        extends 'Class::Accessor::Fast'; # NEEDED!?

        # method BUILD {
        #         my $class = ref($self);
        #         print "class: ", Dumper($class);
        #         my $ns = $schema_class->compose_namespace($class);
        # }

        method producer
        {
                my $producer_class = "Artemis::MCP::Scheduler::PreconditionProducer::".$self->producer;
                eval "use $producer_class";
                return $producer_class->new unless $@;
                return undef;
        }

        method produce ($request)
        {
                if (not $self->producer) {
                        warn "Queue ".$self->name." does not have an associated producer";
                } else {
                        print STDERR "Queue.produce/producer: ", Dumper($self->producer);
                        return $self->producer->produce($request)
                }
        }
        __PACKAGE__->meta->make_immutable(inline_constructor => 0);
}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::Queue;
        our $VERSION = '0.01';
}

1;
