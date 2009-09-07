#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use aliased 'Artemis::MCP::Scheduler::Host';
use aliased 'Artemis::MCP::Scheduler::Controller';
use aliased 'Artemis::MCP::Scheduler::TestRequest';
use aliased 'Artemis::MCP::Scheduler::Algorithm::WFQ';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Queue';
use aliased 'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm';
use aliased 'Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer';

use Test::More tests => 6;

my @hostlist;
my $host = Host->new();
$host->name('bullock');
$host->features({
                 mem      => 8192,
                 vendor   => 'AMD',
                 family   => 15,
                 model    => 67,
                 stepping => 2,
                 revision => '',
                 socket   => 'AM2',
                 cores    => 2,
                 clock    => 2600,
                 l2cache  => 1024,
                 l3cache  => 0
                });
# TODO: "busy" 1/0: $host->state('free');
push @hostlist, $host;

$host = Artemis::MCP::Scheduler::Host->new();
$host->name('dickstone');
$host->features({
                 mem      => 4096,
                 vendor   => 'AMD',
                 family   => 15,
                 model    => 67,
                 stepping => 2,
                 revision => '',
                 socket   => 'AM2',
                 cores    => 2,
                 clock    => 2600,
                 l2cache  => 1024,
                 l3cache  => 0
                });
# TODO: "busy" 1/0: $host->state('free');
push @hostlist, $host;

my $request = Artemis::MCP::Scheduler::TestRequest->new();
my $value = 'mem <= 8000';
$request->requested_features([$value]);
$request->queue('Xen');


my $algorithm = Artemis::MCP::Scheduler::Algorithm->new_with_traits
    ( traits => [WFQ],
      queues => {},
    );
my $queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Xen');
$queue->priority(300);
$queue->producer(Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer->new);
$queue->testrequests([$request]);
$algorithm->add_queue($queue);

$request = Artemis::MCP::Scheduler::TestRequest->new();
$value = 'mem <= 8000';
$request->requested_features([$value]);
$request->queue('kvm');

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('KVM');
$queue->priority(200);
$queue->testrequests([$request]);
$algorithm->add_queue($queue);

$queue = Artemis::MCP::Scheduler::Queue->new();
$queue->name('Kernel');
$queue->priority(10);
$algorithm->add_queue($queue);

my $controller =  Artemis::MCP::Scheduler::Controller->new();
$controller->algorithm($algorithm);

my $job = $controller->get_next_job(\@hostlist);
isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Controller returns a job');
isa_ok($job->host, 'Artemis::MCP::Scheduler::Host', 'Returned Job has a host');
is($job->host->name, 'dickstone', 'Evaluation of feature list in a testrequest');

$host = Artemis::MCP::Scheduler::Host->new();
$host->name('featureless');
# TODO: "busy" 1/0: $host->state('free');
push @hostlist, $host;


$algorithm = Artemis::MCP::Scheduler::Algorithm->new_with_traits
    (
     traits => [DummyAlgorithm],
     queues => {},
    );


$queue = Queue->new();
$queue->name('Xen');
$queue->priority(300);
$queue->producer(DummyProducer->new);

$request = TestRequest->new();
$value = 'mem <= 8000';
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
