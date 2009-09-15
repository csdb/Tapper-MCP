#! /usr/bin/env perl

use strict;
use warnings;

#
# Test whether auto_rerun works as expected
#


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
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_scheduling_run2.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# --------------------------------------------------------------------------------

# --------------------------------------------------

my $algorithm = Algorithm->new_with_traits ( traits => [DummyAlgorithm] );
my $scheduler = Controller->new (algorithm => $algorithm);

# --------------------------------------------------

my $free_hosts;
my $next_job;
my @free_host_names;


$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
my $host = $free_hosts->next;


# Job 1
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts");

$next_job   = $scheduler->get_next_job($free_hosts);
is($next_job->id, 301, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
is($next_job->testrun->shortname, "ccc-kernel", "Shortname testrun");
$scheduler->mark_job_as_running($next_job);

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(bullock dickstone athene bascha)], "free hosts: iring taken ");

$scheduler->mark_job_as_finished($next_job);




# Job 2
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts");

$next_job   = $scheduler->get_next_job($free_hosts);
is($next_job->id, 302, "next fitting host");
is($next_job->host->name, "iring", "fitting host iring");
is($next_job->testrun->shortname, "ccc2-kernel", "Shortname testrun");
$scheduler->mark_job_as_running($next_job);

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(bullock dickstone athene bascha)], "free hosts: iring taken ");

$scheduler->mark_job_as_finished($next_job);




# Job 3
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts");

$next_job   = $scheduler->get_next_job($free_hosts);
is($next_job->testrun->shortname, "ccc-kernel", "Shortname testrun");
is($next_job->host->name, "iring", "fitting host iring");
$scheduler->mark_job_as_running($next_job);

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(bullock dickstone athene bascha)], "free hosts: iring taken ");

$scheduler->mark_job_as_finished($next_job);





# Job 4
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts");

$next_job   = $scheduler->get_next_job($free_hosts);
is($next_job->testrun->shortname, "ccc-kernel", "Shortname testrun");
is($next_job->host->name, "iring", "fitting host iring");
$scheduler->mark_job_as_running($next_job);

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(bullock dickstone athene bascha)], "free hosts: iring taken ");

$scheduler->mark_job_as_finished($next_job);



# Job 5
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(iring bullock dickstone athene bascha)], "free hosts");

$next_job   = $scheduler->get_next_job($free_hosts);
is($next_job->testrun->shortname, "ccc-kernel", "Shortname testrun");
is($next_job->host->name, "iring", "fitting host iring");
$scheduler->mark_job_as_running($next_job);

$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
@free_host_names = map { $_->name } $free_hosts->all;
cmp_bag(\@free_host_names, [qw(bullock dickstone athene bascha)], "free hosts: iring taken ");

$scheduler->mark_job_as_finished($next_job);


done_testing;

