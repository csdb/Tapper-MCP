#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use aliased 'Artemis::MCP::Scheduler::Job';
use aliased 'Artemis::MCP::Scheduler::Controller';
use aliased 'Artemis::MCP::Scheduler::TestRequest';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm';
use aliased 'Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer';

use Artemis::Model 'model';

use Data::Dumper;
use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;

use Test::More;
use Test::Deep;

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

is($scheduler->merged_queue->wanted_length, 3, "wanted_length is count queues");

my $tr_rs = $scheduler->merged_queue->get_testrequests;

is($tr_rs->count, 3, "expected count of elements in merged_queue");

# --------------------------------------------------

my $job;

$job = $tr_rs->next;
is($job->id, 201, "first job id");
is($job->requested_hosts->first->host->name, "bullock", "first job requested_host");
is($job->testrun_id, 2001, "first job testrun_id");

$job = $tr_rs->next;
is($job->id, 301, "second job id");
is($job->requested_hosts->first->host->name, "iring", "second job requested_host");
is($job->testrun_id, 3001, "second job testrun_id");

$job = $tr_rs->next;
is($job->id, 101, "third job");
is($job->requested_hosts->first->host->name, "bascha", "third job requested_host");
is($job->testrun_id, 1001, "third job testrun_id");

# --------------------------------------------------

# MICRO-TODO:
#
# - implement free_hosts in Schema: model("TestrunDB")->resultset("Host")->free_hosts()
my $free_hosts;
my $next_job;
my @free_host_names;

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts: all");
$next_job   = $scheduler->merged_queue->get_first_fitting($free_hosts);
is($next_job->id, 201, "next fitting host");
is($next_job->host->name, "bullock", "fitting host bullock");
$scheduler->mark_job_as_running($next_job);

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring dickstone athene bascha)], "free hosts: bullock taken");
$next_job   = $scheduler->merged_queue->get_first_fitting($free_hosts);
is($next_job->id, 301, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
$scheduler->mark_job_as_running($next_job);

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene bascha)], "free hosts: iring taken");
$next_job   = $scheduler->merged_queue->get_first_fitting($free_hosts);
is($next_job->id, 101, "next fitting host");
is($next_job->host->name, "bascha", "fitting host bascha");
$scheduler->mark_job_as_running($next_job);


$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene)], "free hosts: bascha taken");

done_testing();
