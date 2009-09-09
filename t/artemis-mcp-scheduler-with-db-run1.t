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

# --------------------------------------------------

# MICRO-TODO:
#
# - implement free_hosts in Schema: model("TestrunDB")->resultset("Host")->free_hosts()
my $free_hosts;
my $next_job;
my @free_host_names;


$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
my $host = $free_hosts->next;
diag $host->name;
$host = $free_hosts->next;
diag $host->name;

diag "----------------------------------------";

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
$host = $free_hosts->next;
diag $host->name;
$host = $free_hosts->next;
diag $host->name;

diag "----------------------------------------";

# Job 1

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts: all");
$next_job   = $scheduler->get_next_job($free_hosts);
is($next_job->id, 201, "next fitting host");
is($next_job->host->name, "bullock", "fitting host bullock");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 2, "merged_queue with one job less");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting");
my $job1 = $next_job;

# Job 2

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring dickstone athene bascha)], "free hosts: bullock taken");
$next_job   = $scheduler->get_next_job($free_hosts);
is($next_job->id, 301, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 2, "merged_queue with one job less");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting");
my $job2 = $next_job;

# Job 3

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene bascha)], "free hosts: iring taken");
$next_job = $scheduler->get_next_job($free_hosts);
is($next_job->id, 101, "next fitting host");
is($next_job->host->name, "bascha", "fitting host bascha");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 2, "merged_queue with one job less");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting");
my $job3 = $next_job;

# Intermediate state

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene)], "free hosts: bascha taken");

my $non_scheduled_jobs = model('TestrunDB')->resultset('TestrunScheduling')->search({ mergedqueue_seq => undef, status => "schedule" });
is($non_scheduled_jobs->count, 4, "still have 4 jobs in queues but not in merged_queue");

$next_job = $scheduler->get_next_job($free_hosts);
is($next_job, undef, "Indeed no fitting while all requested machines busy");
is($scheduler->merged_queue->length, 3, "merged_queue filled up on last get_next_job");
is($scheduler->merged_queue->wanted_length, 4, "incremented wanted_length after unsuccessful get_next_job");

# ask once again unsuccessfully
$next_job = $scheduler->get_next_job($free_hosts);
is($next_job, undef, "Again no fitting while all requested machines busy");
is($scheduler->merged_queue->length, 4, "merged_queue filled up on last get_next_job");
is($scheduler->merged_queue->wanted_length, 5, "incremented wanted_length after unsuccessful get_next_job");

# finish Job2
$scheduler->mark_job_as_finished($job2);
is($job2->status, "finished", "job2 finished");
is($job2->host->free, 1, "host of job2 free again");
is($job2->host->name, "iring", "and it is indeed iring");

# check state of merged queue
is($scheduler->merged_queue->length, 4, "merged_queue filled up on last get_next_job");
is($scheduler->merged_queue->wanted_length, 5, "incremented wanted_length after unsuccessful get_next_job");

# Job 4

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available");
$next_job = $scheduler->get_next_job($free_hosts);
is($next_job->id, 302, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 4, "merged_queue filled up to 4");
is($scheduler->merged_queue->wanted_length, 4, "wanted_length unchanged after successful get_first_fitting");
my $job4 = $next_job;


# bis zum bitteren Ende:
#
#  finish Job
#  merged_queue testen
#  free_hosts testen





done_testing();
