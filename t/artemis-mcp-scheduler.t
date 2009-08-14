#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use Artemis::MCP::Scheduler::Host;
use Artemis::MCP::Scheduler::Controller;
use Artemis::MCP::Scheduler::TestRequest;
use Artemis::MCP::Scheduler::Algorithm::WFQ;
use Artemis::MCP::Scheduler::Algorithm::Dummy;
use Artemis::MCP::Scheduler::Producer;

use Test::More tests => 6;

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


my $algorithm = Artemis::MCP::Scheduler::Algorithm::WFQ->new();
my $queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Xen');
$queue->share(300);
$queue->producer(Artemis::MCP::Scheduler::Producer->new);
$queue->testrequests([$request]);
$algorithm->add_queue($queue);


$request = Artemis::MCP::Scheduler::TestRequest->new();
$value = 'Mem <= 8000';
$request->requested_features([$value]);
$request->queue('kvm');

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('KVM');
$queue->share(200);
$queue->testrequests([$request]);
$algorithm->add_queue($queue);

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Kernel');
$queue->share(10);
$algorithm->add_queue($queue);



my $controller =  Artemis::MCP::Scheduler::Controller->new();
$controller->algorithm($algorithm);


my $job = $controller->get_next_job(\@hostlist);
isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Controller returns a job');
isa_ok($job->host, 'Artemis::MCP::Scheduler::Host', 'Returned Job has a host');
is($job->host->name, 'dickstone', 'Evaluation of feature list in a testrequest');

$host = Artemis::MCP::Scheduler::Host->new();
$host->name('featureless');
$host->state('free');
push @hostlist, $host;


$algorithm = Artemis::MCP::Scheduler::Algorithm::Dummy->new();


$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Xen');
$queue->share(300);
$queue->producer(Artemis::MCP::Scheduler::Producer->new);

$request = Artemis::MCP::Scheduler::TestRequest->new();
$value = 'Mem <= 8000';
$request->requested_features([$value]);
$request->queue('Xen');
$queue->testrequests([$request]);

$request = Artemis::MCP::Scheduler::TestRequest->new();
$request->hostnames(['featureless']);
$request->queue('Xen');
unshift @{$queue->testrequests}, $request;

$algorithm->add_queue($queue);

$controller->algorithm($algorithm);

$job = $controller->get_next_job(\@hostlist);
isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Controller returns a job');
isa_ok($job->host, 'Artemis::MCP::Scheduler::Host', 'Returned Job has a host');
is($job->host->name, 'featureless', 'Evaluation of feature list in a testrequest');
