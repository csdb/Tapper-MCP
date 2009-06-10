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
$host->available_features({Mem => 8192, Vendor => 'AMD', Family => 15, Model => 67, Stepping => 2, Revision => '', Socket => 'AM2', Number_of_cores => 2, Clock => 2600, L2_Cache => 1024, L3_Cache => 0});
$host->state('free');
push @hostlist, $host;

$host = Artemis::MCP::Scheduler::Host->new();
$host->name('dickstone');
$host->available_features({Mem => 4096, Vendor => 'AMD', Family => 15, Model => 67, Stepping => 2, Revision => '', Socket => 'AM2', Number_of_cores => 2, Clock => 2600, L2_Cache => 1024, L3_Cache => 0});
$host->state('free');
push @hostlist, $host;

my $request = Artemis::MCP::Scheduler::TestRequest->new();
my $value = 'Mem <= 8000';
$request->requested_features([$value]);
$request->queue('Xen');


my $wfq = Artemis::MCP::Scheduler::Algorithm::WFQ->new();
my $queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Xen');
$queue->share(300);
$queue->producer(Artemis::MCP::Scheduler::Producer->new);
$queue->testrequests([$request]);
$wfq->add_queue($queue);


$request = Artemis::MCP::Scheduler::TestRequest->new();
$value = 'Mem <= 8000';
$request->requested_features([$value]);
$request->queue('kvm');

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('KVM');
$queue->share(200);
$queue->testrequests([$request]);
$wfq->add_queue($queue);

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Kernel');
$queue->share(10);
$wfq->add_queue($queue);



my $primat =  Artemis::MCP::Scheduler::Primate->new();
$primat->algorithm($wfq);


my $job = $primat->get_next_job(\@hostlist);
isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Primate returns a job');
isa_ok($job->host, 'Artemis::MCP::Scheduler::Host', 'Returned Job has a host');
is($job->host->name, 'dickstone', 'Evaluation of feature list in a testrequest');
