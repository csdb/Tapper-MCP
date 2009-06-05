#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use Artemis::MCP::Scheduler::Host;
use Artemis::MCP::Scheduler::Primate;
use Artemis::MCP::Scheduler::TestRequest;

use Test::More tests => 2;

my @hostlist;
my $host = Artemis::MCP::Scheduler::Host->new();
$host->name('bullock');
$host->features({mem => 8192, cpu => {Vendor => 'AMD', Family => 15, Model => 67, Stepping => 2, Revision => '', Socket => 'AM2', Number_of_cores => 2, Clock => 2600, 	l2_Cache => 1024, l3_Cache => 0}});
$host->state('free');
push @hostlist, $host;

$host = Artemis::MCP::Scheduler::Host->new();
$host->name('dickstone');
$host->features({mem => 4096, cpu => {Vendor => 'AMD', Family => 15, Model => 67, Stepping => 2, Revision => '', Socket => 'AM2', Number_of_cores => 2, Clock => 2600, 	l2_Cache => 1024, l3_Cache => 0}});
$host->state('free');
push @hostlist, $host;

my $primat =  Artemis::MCP::Scheduler::Primate->new();
$primat->hostlist(\@hostlist);

my $request = Artemis::MCP::Scheduler::TestRequest->new();
$request->featureset({mem => 8000});
$request->queue('kvm');

my $job = $primat->get_next_job();
isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Primate returns a job');
is($job->hostname, 'bullock', 'Evaluation of feature list in a testrequest');
