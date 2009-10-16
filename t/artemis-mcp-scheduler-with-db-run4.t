#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use aliased 'Artemis::MCP::Scheduler::Job';
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
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_scheduling_run4.yml' );
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

$free_hosts = model("TestrunDB")->resultset("Host");
while (my $host = $free_hosts->next) {
        $host->free(0);
        $host->update;
}

$next_job = $scheduler->get_next_job();
is($next_job, undef, "no job since all hosts in use");
is($scheduler->merged_queue->length, 3, "merged_queue full");
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged");

my $bound_host = model("TestrunDB")->resultset("Host")->find(10); # host bound to kernel queue
$bound_host->free(1);
$bound_host->update();

# get no job since only host "kernelbound" is free but next kernel test requests "iring"
$next_job = $scheduler->get_next_job();
is($next_job, undef, "no job since all hosts in use");
is($scheduler->merged_queue->length, 3, "merged_queue full");
is($scheduler->algorithm->lookup_next_queue()->name, 'Kernel', 'Next queue will be KVM');
is($scheduler->merged_queue->wanted_length, 3, "wanted_length unchanged because free host not bound to next queue");

$bound_host = model("TestrunDB")->resultset("Host")->find(11);
$bound_host->free(1);
$bound_host->update();

$next_job = $scheduler->get_next_job();
is($next_job, undef, "no job since all hosts in use");
is($scheduler->merged_queue->length, 3, "merged_queue full");
is($scheduler->algorithm->lookup_next_queue()->name, 'Kernel', 'Next queue will be KVM');
is($scheduler->merged_queue->wanted_length, 4, "increases wanted_length because free host matches next queue");

$next_job = $scheduler->get_next_job();
is($next_job, undef, "no job since all hosts in use");
is($scheduler->merged_queue->length, 4, "merged_queue full");
is($scheduler->algorithm->lookup_next_queue()->name, 'Xen', 'Next queue will be KVM');
is($scheduler->merged_queue->wanted_length, 5, "increases wanted_length because free host matches next queue");

done_testing();
