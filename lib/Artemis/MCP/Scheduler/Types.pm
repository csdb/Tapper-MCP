package Artemis::MCP::Scheduler::Types;

# predeclare our own types
use MooseX::Types 
    -declare => [qw(
                           Queue
                           TestrunScheduling
                  )];

use MooseX::Types::Moose qw/HashRef/;

class_type Queue, { class => 'Artemis::MCP::Scheduler::Schema::TestrunDB::Result::Queue' };
coerce Queue,
    from HashRef,
    via { Artemis::MCP::Scheduler::Schema::TestrunDB::Result::Queue->new(%$_) };

class_type TestrunScheduling, { class => 'Artemis::MCP::Scheduler::Schema::TestrunDB::Result::TestrunScheduling' };
coerce TestrunScheduling,
    from HashRef,
    via { Artemis::MCP::Scheduler::Schema::TestrunDB::Result::TestrunScheduling->new(%$_) };

1;

