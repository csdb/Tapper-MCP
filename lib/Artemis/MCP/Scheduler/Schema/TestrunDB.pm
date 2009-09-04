package Artemis::MCP::Scheduler::Schema::TestrunDB;

use 5.010;
use strict;
use warnings;

use Artemis::Config;
use Data::Dumper;

use Symbol::Table;

use parent "Artemis::Schema::TestrunDB";

my $composed_schema = Artemis::Schema::TestrunDB->compose_namespace(__PACKAGE__."::Result");
my $schema = $composed_schema->clone;

1;


