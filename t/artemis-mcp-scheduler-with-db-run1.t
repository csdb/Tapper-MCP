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

my $free_hosts;
my $next_job;
my @free_host_names;


# Job 1

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts: all");
$next_job   = $scheduler->get_next_job();
is($next_job->id, 201, "next fitting host");
is($next_job->host->name, "bullock", "fitting host bullock");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 2, "merged_queue with one job less");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting 1");
my $job1 = $next_job;

# Job 2

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring dickstone athene bascha)], "free hosts: bullock taken");
$next_job   = $scheduler->get_next_job();
is($next_job->id, 301, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 2, "merged_queue with one job less");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting 2");
my $job2 = $next_job;

# Job 3

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene bascha)], "free hosts: iring taken");
$next_job = $scheduler->get_next_job();
is($next_job->id, 101, "next fitting host");
is($next_job->host->name, "bascha", "fitting host bascha");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 2, "merged_queue with one job less");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting 2");
my $job3 = $next_job;

# Intermediate state

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene)], "free hosts: bascha taken");

my $non_scheduled_jobs = model('TestrunDB')->resultset('TestrunScheduling')->non_scheduled_jobs;
is($non_scheduled_jobs->count, 4, "still have 4 jobs in queues but not in merged_queue");

$next_job = $scheduler->get_next_job();
is($next_job, undef, "Indeed no fitting while all requested machines busy");
is($scheduler->merged_queue->length, 3, "merged_queue filled up on last get_next_job");
is($scheduler->merged_queue->wanted_length, 4, "incremented wanted_length after unsuccessful get_next_job");

# ask once again unsuccessfully
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting while all requested machines busy");

# check state of merged queue BEFORE FINISH
is($scheduler->merged_queue->length, 4, "merged_queue filled up on last get_next_job");
is($scheduler->merged_queue->wanted_length, 5, "incremented wanted_length after unsuccessful get_next_job");

# finish Job2
$scheduler->mark_job_as_finished($job2);
is($job2->status, "finished", "job2 finished");
is($job2->host->free, 1, "host of job2 free again");
is($job2->host->name, "iring", "and it is indeed iring");
is($job2->queue->name, "Kernel", "and it is a Kernel job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 4, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 5, "finishing a job does not interfere with merged_queue wanted_length");

# Job 4

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available");
$next_job = $scheduler->get_next_job();
is($next_job->id, 302, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
is($next_job->queue->name, "Kernel", "it is a Kernel job");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 4, "merged_queue filled up");
is($scheduler->merged_queue->wanted_length, 4, "wanted_length unchanged after successful get_first_fitting 4");
my $job4 = $next_job;


# intermediate state
$non_scheduled_jobs = model('TestrunDB')->resultset('TestrunScheduling')->non_scheduled_jobs;
is($non_scheduled_jobs->count, 1, "only 1 job not yet in merged_queue");
is($non_scheduled_jobs->first->id, 103, "it is the last Xen job by id");
is($non_scheduled_jobs->first->queue->name, "Xen", "it is the last Xen job by queue-name");

my @merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
my @merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( KVM Xen KVM Kernel ) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 202, 102, 203, 303 ],       "expected state of merged queue by id");


# finish Job 4
$scheduler->mark_job_as_finished($job4);
is($job4->status, "finished", "job4 finished");
is($job4->host->free, 1, "host of job4 free again");
is($job4->host->name, "iring", "and it is indeed iring");
is($job4->queue->name, "Kernel", "and it is a Kernel job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 4, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 4, "finishing a job does not interfere with merged_queue wanted_length");

# Job 5

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available");
$next_job = $scheduler->get_next_job();
is($next_job->id, 303, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
is($next_job->queue->name, "Kernel", "it is a Kernel job");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 3, "merged_queue filled up");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting 5");
my $job5 = $next_job;

# check queue, no new because merged queue is full
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( KVM Xen KVM ) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 202, 102, 203 ],     "expected state of merged queue by id");


# try an unsuccessful one

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene)], "free hosts: only useless hosts");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 3, "merged_queue filled up");
is($scheduler->merged_queue->wanted_length, 4, "wanted_length increase after unsuccessful get_next_job 6");


# Finish Job 5

$scheduler->mark_job_as_finished($job5);
is($job4->status, "finished", "job5 finished");
is($job4->host->free, 1, "host of job5 free again");
is($job4->host->name, "iring", "and it is indeed iring");
is($job4->queue->name, "Kernel", "and it is a Kernel job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 3, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 4, "finishing a job does not interfere with merged_queue wanted_length");


# try an unsuccessful one

# although we have a free host it does not fit any of the requested hosts in merged_queue
# but the last Xen job get slurped into merged queue

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available again");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 4, "merged_queue filled up");
is($scheduler->merged_queue->wanted_length, 5, "wanted_length unchanged after successful get_first_fitting 7");

# trying the same no-success again

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available again");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 4, "merged_queue tried to fill up and no more available");
is($scheduler->merged_queue->wanted_length, 5, "wanted_length unchanged after successful get_first_fitting 8");


# trying the same no-success a third time

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available again");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 4, "merged_queue tried to fill up and no more available");
is($scheduler->merged_queue->wanted_length, 5, "wanted_length unchanged after successful get_first_fitting 8");


# Finish Job 1

$scheduler->mark_job_as_finished($job1);
is($job1->status, "finished", "job1 finished");
is($job1->host->free, 1, "host of job1 free again");
is($job1->host->name, "bullock", "and it is indeed bullock");
is($job1->queue->name, "KVM", "and it is a KVM job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 4, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 5, "finishing a job does not interfere with merged_queue wanted_length");


# check queue
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( KVM Xen KVM Xen) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 202, 102, 203, 103 ],     "expected state of merged queue by id");


# Job 6

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bullock)], "free hosts: iring and bullock available");
$next_job = $scheduler->get_next_job();
is($next_job->id, 202, "next fitting host");
is($next_job->host->name, "bullock", "fitting host bullock");
is($next_job->queue->name, "KVM", "it is a KVM job");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 3, "merged_queue filled up");
is($scheduler->merged_queue->wanted_length, 4, "wanted_length unchanged after successful get_first_fitting");
my $job6 = $next_job;

# check queue, no new because merged queue is full
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( Xen KVM Xen) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 102, 203, 103 ],     "expected state of merged queue by id");


# Finish Job 3

$scheduler->mark_job_as_finished($job3);
is($job3->status, "finished", "job3 finished");
is($job3->host->free, 1, "host of job3 free again");
is($job3->host->name, "bascha", "and it is indeed bascha");
is($job3->queue->name, "Xen", "and it is a Xen job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 3, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 4, "finishing a job does not interfere with merged_queue wanted_length");

# check queue
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( Xen KVM Xen) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 102, 203, 103 ],     "expected state of merged queue by id");

# check free hosts
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bascha)], "free hosts: iring and bascha available");

# currently running: Job 6-bullock-KVM

# Job 7

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bascha)], "free hosts: iring and bascha available");
$next_job = $scheduler->get_next_job();
is($next_job->id, 102, "next fitting host");
is($next_job->host->name, "bascha", "fitting host bascha");
is($next_job->queue->name, "Xen", "it is a Xen job");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 2, "merged_queue filled up");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged after successful get_first_fitting");
my $job7 = $next_job;

# check queue, no new because merged queue is full
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( KVM Xen) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 203, 103 ],     "expected state of merged queue by id");

# check free hosts
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring )], "free hosts: iring available");

# currently running: Job 6-bullock-KVM, 7-bascha-Xen

# Finish Job 7

$scheduler->mark_job_as_finished($job7);
is($job7->status, "finished", "job7 finished");
is($job7->host->free, 1, "host of job7 free again");
is($job7->host->name, "bascha", "and it is indeed bascha");
is($job7->queue->name, "Xen", "and it is a Xen job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 2, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 3, "finishing a job does not interfere with merged_queue wanted_length");

# check queue
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( KVM Xen) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 203, 103 ],     "expected state of merged queue by id");

# check free hosts
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bascha)], "free hosts: iring and bascha available");

# currently running: Job 6-bullock-KVM

# Finish Job 6

$scheduler->mark_job_as_finished($job6);
is($job6->status, "finished", "job6 finished");
is($job6->host->free, 1, "host of job7 free again");
is($job6->host->name, "bullock", "and it is indeed bullock");
is($job6->queue->name, "KVM", "and it is a KVM job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 2, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 3, "finishing a job does not interfere with merged_queue wanted_length");

# check queue
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( KVM Xen) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 203, 103 ],     "expected state of merged queue by id");

# check free hosts
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bascha bullock)], "free hosts: iring, bascha and bullock available");

# currently running: none

# Job 8

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bascha bullock)], "free hosts: iring, bascha and bullock available");
$next_job = $scheduler->get_next_job();
is($next_job->id, 203, "next fitting host");
is($next_job->host->name, "bullock", "fitting host bullock");
is($next_job->queue->name, "KVM", "it is a KVM job");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 1, "merged_queue length");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length after successful get_first_fitting");
my $job8 = $next_job;

# check queue, no new because merged queue is full
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( Xen ) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ 103 ],       "expected state of merged queue by id");

# check free hosts
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bascha)], "free hosts: iring and bascha available");

# currently running: Job 8-bullock-KVM

# Job 9

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bascha )], "free hosts: iring, bascha available");
$next_job = $scheduler->get_next_job();
is($next_job->id, 103, "next fitting host");
is($next_job->host->name, "bascha", "fitting host bascha");
is($next_job->queue->name, "Xen", "it is a Xen job");
$scheduler->mark_job_as_running($next_job);
is($scheduler->merged_queue->length, 0, "merged_queue length");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length after successful get_first_fitting");
my $job9 = $next_job;

# check queue, no new because merged queue is full
@merged_queue_jobs    = map { $_->queue->name } $scheduler->merged_queue->get_testrequests->all;
@merged_queue_job_ids = map { $_->id }  $scheduler->merged_queue->get_testrequests->all;

is_deeply(\@merged_queue_jobs,    [ qw( ) ], "expected state of merged queue by queue-name");
is_deeply(\@merged_queue_job_ids, [ ],       "expected state of merged queue by id");

# check free hosts
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring )], "free hosts: iring available");

# currently running: Job 8-bullock-KVM, Job 9-bascha-Xen


# try an unsuccessful get_next_job

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 0, "merged_queue length still 0");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged although unsuccessful get but should not grow more");

# try second time unsuccessfully

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 0, "merged_queue length still 0");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged although unsuccessful get but should not grow more");

# try third time unsuccessfully, just to be sure

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring)], "free hosts: iring available");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 0, "merged_queue length still 0");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged although unsuccessful get but should not grow more");


# currently running: Job 8-bullock-KVM, Job 9-bascha-Xen

# Finish Job 8

$scheduler->mark_job_as_finished($job8);
is($job8->status, "finished", "job8 finished");
is($job8->host->free, 1, "host of job8 free again");
is($job8->host->name, "bullock", "and it is indeed bullock");
is($job8->queue->name, "KVM", "and it is a KVM job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 0, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 3, "finishing a job does not interfere with merged_queue wanted_length");

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bullock)], "free hosts: iring, bullock available");

# currently running: Job 9-bascha-Xen

# Finish Job 9

$scheduler->mark_job_as_finished($job9);
is($job9->status, "finished", "job9 finished");
is($job9->host->free, 1, "host of job9 free again");
is($job9->host->name, "bascha", "and it is indeed bascha");
is($job9->queue->name, "Xen", "and it is a Xen job");

# check state of merged queue AFTER FINISH
is($scheduler->merged_queue->length, 0, "finishing a job does not interfere with merged_queue length");
is($scheduler->merged_queue->wanted_length, 3, "finishing a job does not interfere with merged_queue wanted_length");

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bullock bascha)], "free hosts: iring, bullock, bascha available");

# currently running: none


# try an unsuccessful get_next_job

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bullock bascha)], "free hosts: iring, bullock, bascha available");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 0, "merged_queue length still 0");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged although unsuccessful get but should not grow more");

# try second time unsuccessfully

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bullock bascha)], "free hosts: iring, bullock, bascha available");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 0, "merged_queue length still 0");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged although unsuccessful get but should not grow more");

# try third time unsuccessfully, just to be sure

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(dickstone athene iring bullock bascha)], "free hosts: iring, bullock, bascha available");
$next_job = $scheduler->get_next_job();
is($next_job, undef, "Again no fitting for available machines");

is($scheduler->merged_queue->length, 0, "merged_queue length still 0");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged although unsuccessful get but should not grow more");



done_testing();

# - drop "xentest.pl", now all in MCP
