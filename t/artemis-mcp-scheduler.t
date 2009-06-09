#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use Artemis::MCP::Scheduler::Host;
use Artemis::MCP::Scheduler::Primate;
use Artemis::MCP::Scheduler::TestRequest;
use Artemis::MCP::Scheduler::Algorithm::WFQ;
use Artemis::MCP::Scheduler::Producer;

use Test::More tests => 3;

my @hostlist;
my $host = Artemis::MCP::Scheduler::Host->new();
$host->name('bullock');
$host->available_features({mem => 8192, cpu => {Vendor => 'AMD', Family => 15, Model => 67, Stepping => 2, Revision => '', Socket => 'AM2', Number_of_cores => 2, Clock => 2600, l2_Cache => 1024, l3_Cache => 0}});
$host->state('free');
push @hostlist, $host;

$host = Artemis::MCP::Scheduler::Host->new();
$host->name('dickstone');
$host->available_features({mem => 4096, cpu => {Vendor => 'AMD', Family => 15, Model => 67, Stepping => 2, Revision => '', Socket => 'AM2', Number_of_cores => 2, Clock => 2600, l2_Cache => 1024, l3_Cache => 0}});
$host->state('free');
push @hostlist, $host;


my $wfq = Artemis::MCP::Scheduler::Algorithm::WFQ->new();
my $queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Xen');
$queue->share(300);
$queue->producer(Artemis::MCP::Scheduler::Producer->new);
$wfq->add_queue($queue);

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('KVM');
$queue->share(200);
$wfq->add_queue($queue);

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Kernel');
$queue->share(100);
$wfq->add_queue($queue);



my $primat =  Artemis::MCP::Scheduler::Primate->new();
$primat->algorithm($wfq);
$primat->hostlist(\@hostlist);

my $request = Artemis::MCP::Scheduler::TestRequest->new();
my $value = 'mem >= 8000';
$request->requested_features([$value]);
$request->queue('kvm');

my $job = $primat->get_next_job();
isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Primate returns a job');
isa_ok($job->host, 'Artemis::MCP::Scheduler::Host', 'Returned Job has a host');
is($job->host->name, 'bullock', 'Evaluation of feature list in a testrequest');
