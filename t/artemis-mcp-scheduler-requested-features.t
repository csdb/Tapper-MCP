#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use aliased 'Artemis::MCP::Scheduler::Controller';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm';

use Artemis::Model 'model';

use Data::Dumper;
use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;

use Test::More;
use Test::Deep;

# --------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_scheduling_features.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems_features.yml' );
# --------------------------------------------------------------------------------

# --------------------------------------------------

my $algorithm = Algorithm->new_with_traits ( traits => [DummyAlgorithm] );
my $scheduler = Controller->new (algorithm => $algorithm);

# --------------------------------------------------


my $next_job = $scheduler->get_next_job();
is($next_job->host->name, "kobold", "fitting host kobold");
$scheduler->mark_job_as_running($next_job);
my $job1=$next_job;

$next_job = $scheduler->get_next_job();
is($next_job, undef, "no job since no other machine with ecc");


$scheduler->mark_job_as_finished($job1);


done_testing();
