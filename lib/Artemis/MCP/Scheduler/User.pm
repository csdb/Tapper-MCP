package Artemis::MCP::Scheduler::User;

use Moose;
use 5.010;

extends 'Artemis::Schema::TestrunDB::Result::User';
extends "Class::Accessor::Fast";

has hotstuff => (is => 'rw', isa => "Str");
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

