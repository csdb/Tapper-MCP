#!/usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;
use Log::Log4perl;
use Test::Fixture::DBIC::Schema;
use Test::MockModule;

use Artemis::Model 'model';
use Artemis::Schema::TestTools;

use Artemis::MCP::Master;


use Test::More tests => 7;

BEGIN { use_ok('Artemis::MCP::Master'); }

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# -----------------------------------------------------------------------------------------------------------------
my $mockmaster = Test::MockModule->new('Artemis::MCP::Master');
$mockmaster->mock('console_open',sub{return "mocked console_open";});
$mockmaster->mock('console_close',sub{return "mocked console_close";});

my $mockchild = Test::MockModule->new('Artemis::MCP::Child');
$mockchild->mock('runtest_handling',sub{return "mocked runtest_handling";});


my $master   = Artemis::MCP::Master->new();
my $retval;

isa_ok($master, 'Artemis::MCP::Master');

$retval = $master->console_open();
is($retval, "mocked console_open", 'Mocking console_open');
$retval = $master->console_close();
is($retval, "mocked console_close", 'Mocking console_close');


$retval = $master->set_interrupt_handlers();
is($retval, 0, 'Set interrupt handlers');

$retval = $master->prepare_server();
is($retval, 0, 'Setting object attributes');
isa_ok($master->{readset}, 'IO::Select', 'Readset attribute');


