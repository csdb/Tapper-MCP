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

# --------------------------------------------------

my $algorithm = Algorithm->new_with_traits ( traits => [DummyAlgorithm] );
my $scheduler = Controller->new (algorithm => $algorithm);

ok ($scheduler->algorithm->queues, "algorithm and queues");
ok ($scheduler->algorithm->queues->{KVM},    "KVM queue");
ok ($scheduler->algorithm->queues->{Kernel}, "Kernel queue");
ok ($scheduler->algorithm->queues->{Xen},    "Xen queue");

# --------------------------------------------------

diag Dumper($scheduler->merged_queue);
is($scheduler->merged_queue->wanted_length, 3, "wanted_length is count queues");

$scheduler->fill_merged_queue;

my $tr_rs = $scheduler->merged_queue->get_testrequests;

is($tr_rs->count, 3, "expected count of elements in merged_queue");

# --------------------------------------------------

#diag Dumper($tr_rs);
my $job;

$job = $tr_rs->next;
is($job->id, 201, "first job id");
is($job->testrun_id, 2001, "first job testrun_id");

$job = $tr_rs->next;
is($job->id, 301, "second job id");
is($job->testrun_id, 3001, "second job testrun_id");

$job = $tr_rs->next;
is($job->id, 101, "third job");
is($job->testrun_id, 1001, "third job testrun_id");

# --------------------------------------------------

# MICRO-TODO:
# - rebase brach "scheduler" on "master"
# - checken, ob available_features in systems.yml ok
# - create Artemis::MCP::Scheduler::Schema::HardwareDB like ...::TestrunDB
# - check their derived additional methods (Artemis::Model::get_hardwaredb_overview)
# - check where model("HardwareDB") is currently used, fix this to use Artemis::MCP::Scheduler::Model->model();
#   * it is used in Artemis::Model.get_systems_id_for_hostname() which calls model() again
#   * check that this calls the derived class  Artemis::MCP::Scheduler::Model.model()
#   * even if it would use the "wrong" (base) HardwareDB this would do the Right Thing, because we just want to query on host<-->lid mapping
#
# - write get_first_fitting according to current Artemis::MCP::Scheduler::Schema::TestrunDB::Result::TestrunScheduling

my $free_hosts = model("TestrunDB")->resultset("Host");
my $next_job   = $scheduler->merged_queue->get_first_fitting($free_hosts);
is($next_job->id, 201, "next fitting host");

# delete the following 2 lines, once the 3 lines above work

my $next_job = $scheduler->get_next_job;
is ($next_job->id, 201, "next job is first job from merged_queue");

# --------------------------------------------------


done_testing();
