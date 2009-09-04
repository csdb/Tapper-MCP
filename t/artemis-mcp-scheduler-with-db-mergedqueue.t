#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use aliased 'Artemis::MCP::Scheduler::Job';
use aliased 'Artemis::MCP::Scheduler::Host';
use aliased 'Artemis::MCP::Scheduler::Queue';
use aliased 'Artemis::MCP::Scheduler::Controller';
use aliased 'Artemis::MCP::Scheduler::TestRequest';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm';
use aliased 'Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer';
use aliased 'Artemis::MCP::Scheduler::OfficialHosts';
use aliased 'Artemis::MCP::Scheduler::OfficialQueues';

use Artemis::Model 'model';

use Data::Dumper;
use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;

use Test::More;

# --------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_scheduling_run1.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# --------------------------------------------------------------------------------

#model("TestrunDB");

my $algorithm = Algorithm->new_with_traits ( traits => [DummyAlgorithm] );

my $scheduler = Controller->new (algorithm => $algorithm);

ok ($scheduler->algorithm->queues, "algorithm and queues");
ok ($scheduler->algorithm->queues->{KVM},    "KVM queue");
ok ($scheduler->algorithm->queues->{Kernel}, "Kernel queue");
ok ($scheduler->algorithm->queues->{Xen},    "Xen queue");

diag Dumper($scheduler->merged_queue);
is($scheduler->merged_queue->wanted_length, 3, "wanted_length is count queues");

$scheduler->fill_merged_queue;

# while ($scheduler->merged_queue->get_testrequests) {
#         diag Dumper($_);
# }

ok(1, "dummy");

done_testing();
