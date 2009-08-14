#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use Artemis::MCP::Scheduler::Host;
use Artemis::MCP::Scheduler::Controller;
use Artemis::MCP::Scheduler::TestRequest;
use Artemis::MCP::Scheduler::Algorithm::Dummy;
use Artemis::MCP::Scheduler::Producer;

use Test::More tests => 6;

my @hostlist = @{ Artemis::MCP::Scheduler::OfficialHosts->new->hostlist };

my $scheduler =  Artemis::MCP::Scheduler::Controller->new;
$scheduler->algorithm->queues(Artemis::MCP::Scheduler::OfficialQueues->new->queuelist);
$scheduler->algorithm->queues->{Xen}->{testrequests} = [
                                                        Artemis::MCP::Scheduler::TestRequest->new
                                                        (
                                                         queue              => 'Xen',
                                                         requested_features => ['Mem <= 8000'],
                                                        ),
                                                       ] ;

$scheduler->algorithm->queues->{KVM}{testrequests} = [
                                                      Artemis::MCP::Scheduler::TestRequest->new
                                                      ( queue              => 'KVM',
                                                        requested_features => [ 'Mem <= 8000' ],
                                                      ),
                                                     ];

my $job = $scheduler->get_next_job(\@hostlist);

isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Controller returns a job');
isa_ok($job->host, 'Artemis::MCP::Scheduler::Host', 'Returned Job has a host');
is($job->host->name, 'dickstone', 'Evaluation of feature list in a testrequest');

push @hostlist, Artemis::MCP::Scheduler::Host->new
    (
     name => 'featureless',
     state => 'free'
    );

$algorithm = Artemis::MCP::Scheduler::Algorithm::Dummy->new();

my $queue = Artemis::MCP::Scheduler::Queue->new
    (
     name     => 'Xen',
     share    => 300,
     producer => Artemis::MCP::Scheduler::Producer->new,
     testrequests => [
                      Artemis::MCP::Scheduler::TestRequest->new
                      (
                       requested_features => ['Mem <= 8000'],
                       queue => 'Xen',
                      )
                     ],
    );

my $request = Artemis::MCP::Scheduler::TestRequest->new
    (
     hostnames => [ 'featureless' ],
     queue => 'Xen',
    );
unshift @{$queue->testrequests}, $request;

$algorithm->add_queue($queue);
$scheduler->algorithm($algorithm);

$job = $scheduler->get_next_job(\@hostlist);

isa_ok($job, 'Artemis::MCP::Scheduler::Job', 'Scheduler returns a job');
isa_ok($job->host, 'Artemis::MCP::Scheduler::Host', 'Returned Job has a host');
is($job->host->name, 'featureless', 'Evaluation of feature list in a testrequest');

