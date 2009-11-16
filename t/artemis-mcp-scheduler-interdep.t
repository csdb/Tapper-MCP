#!/usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;
use Log::Log4perl;
use Test::Fixture::DBIC::Schema;

use Artemis::MCP::Scheduler::MergedQueue;
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm';
use aliased 'Artemis::MCP::Scheduler::Controller';

use Artemis::Model 'model';
use Artemis::Schema::TestTools;

use Test::More;

my $string = "
log4perl.rootLogger           = INFO, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout";
Log::Log4perl->init(\$string);

my $algorithm = Algorithm->new_with_traits ( traits => [DummyAlgorithm] );
my $scheduler = Controller->new (algorithm => $algorithm);


# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/scenario_testruns.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# -----------------------------------------------------------------------------------------------------------------

my $tr = model('TestrunDB')->resultset('Testrun')->find(1001);
ok($tr->scenario_element, 'Testrun 1001 is part of a scenario');
is($tr->scenario_element->peer_elements->count, 2, 'Number of test runs in scenario');

is($scheduler->merged_queue->length, 0, "merged_queue is empty at start");

$scheduler->merged_queue->add($tr->testrun_scheduling);
is($scheduler->merged_queue->length, 2, "2 elements in merged_queue after adding scenario");

my @id = map { $_->testrun->id} $scheduler->merged_queue->get_testrequests->all;
is_deeply( [ @id ], [ 1001, 1002 ], 'Testruns in Merged queue');

done_testing();
