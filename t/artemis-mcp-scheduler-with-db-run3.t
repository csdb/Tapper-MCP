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

#---------------------------------------------------------
#
#  No merged_queue increase when no free hosts
# 
#---------------------------------------------------------

# Queue bound tests
$free_hosts = model("TestrunDB")->resultset("Host")->free_hosts;
while (my $host = $free_hosts->next) {
        $host->free(0);
        $host->update;
}

$next_job = $scheduler->get_next_job();
is($next_job, undef, "No fitting since no free machines");

is($scheduler->merged_queue->length, 3, "merged_queue full");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged");

$next_job = $scheduler->get_next_job();
is($next_job, undef, "No fitting since no free machines");

is($scheduler->merged_queue->length, 3, "merged_queue full");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged");

$next_job = $scheduler->get_next_job();
is($next_job, undef, "No fitting since no free machines");

is($scheduler->merged_queue->length, 3, "merged_queue full");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged");


done_testing();
