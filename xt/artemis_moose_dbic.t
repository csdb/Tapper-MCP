#! /usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

use lib "xt";
use Data::Dumper;
use aliased "Artemis::MCP::Scheduler::User";
use Foo;

my $user = User->new({ hotstuff => "Affe" }); # DBIC takes hashrefs
diag Dumper($user);
my $foo  = Foo->new;
$foo->hello($user);

ok(1, "dummy");
