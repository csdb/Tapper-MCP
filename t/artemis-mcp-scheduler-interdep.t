#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;
use File::Temp 'tempdir';
use Log::Log4perl;
use Test::Fixture::DBIC::Schema;
use YAML;

use Artemis::MCP::Scheduler::MergedQueue;
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm';
use aliased 'Artemis::MCP::Scheduler::Controller';

use Artemis::Model 'model';
use Artemis::Schema::TestTools;
use Artemis::Config;
use Artemis::MCP::Config;

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

my @next_jobs   = $scheduler->get_next_job();
is(scalar @next_jobs, 0, 'Hold job back until scenario is fully fitted');

@next_jobs   = $scheduler->get_next_job();
is(scalar @next_jobs, 2, 'Return all jobs when scenario is fully fitted');

is($next_jobs[0]->testrun->scenario_element->peer_elements, 2, 'Number of peers including $self');
my $dir = tempdir( CLEANUP => 1 );
my $config = Artemis::Config->subconfig;

$config->{paths}{sync_path} = $dir;
my $testrun = $next_jobs[0]->testrun;
$config->{testrun} = $testrun->id;


my $mcp_conf = Artemis::MCP::Config->new($next_jobs[0]->testrun->id);
$config      = $mcp_conf->get_common_config();
if (ref($config) eq 'HASH') {
        pass('Returned config is a hash ref');
} else {
        fail("Get_common_config returned error string $config");
}

my $syncfile = $config->{paths}{sync_path}."/".$testrun->scenario_element->scenario_id."/syncfile";
ok(-e $syncfile, "Syncfile $syncfile exists");
eval
{
        my $peers = YAML::LoadFile($syncfile);
        is(ref $peers, 'ARRAY', 'Array of hosts in sync file');
};
fail('No valid YAML in syncfile: $@') if $@;

done_testing();
