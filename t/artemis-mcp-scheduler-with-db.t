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
push @hostlist, Artemis::MCP::Scheduler::Host->new
    (
     name               =>'bullock',
     state              => 'free',
     available_features => {
                            Mem             => 8192,
                            Vendor          => 'AMD',
                            Family          => 15,
                            Model           => 67,
                            Stepping        => 2,
                            Revision        => '',
                            Socket          => 'AM2',
                            Number_of_cores => 2,
                            Clock           => 2600,
                            L2_Cache        => 1024,
                            L3_Cache        => 0
                           },
    );

push @hostlist, Artemis::MCP::Scheduler::Host->new
    (
     name               => 'dickstone',
     state              => 'free',
     available_features => {
                            Mem             => 4096,
                            Vendor          => 'AMD',
                            Family          => 15,
                            Model           => 67,
                            Stepping        => 2,
                            Revision        => '',
                            Socket          => 'AM2',
                            Number_of_cores => 2,
                            Clock           => 2600,
                            L2_Cache        => 1024,
                            L3_Cache        => 0
                           },
     );

my $algorithm = Artemis::MCP::Scheduler::Algorithm::WFQ->new();

$algorithm->add_queue
    (Artemis::MCP::Scheduler::Queue->new
     ( name         => 'Xen',
       share        => 300,
       producer     => Artemis::MCP::Scheduler::Producer->new,
       testrequests => [
                        Artemis::MCP::Scheduler::TestRequest->new
                        (
                         requested_features => ['Mem <= 8000'],
                         queue              => 'Xen',
                        ),
                       ],
     )
    );

$algorithm->add_queue
    ( Artemis::MCP::Scheduler::Queue->new
      ( name => 'KVM',
        share => 200,
        testrequests => [
                         Artemis::MCP::Scheduler::TestRequest->new
                         ( queue              => 'kvm',
                           requested_features => [ 'Mem <= 8000' ],
                         )
                        ],
      )
    );


$algorithm->add_queue
    (Artemis::MCP::Scheduler::Queue->new
     ( name => 'Kernel',
       share => 10,
     ),
    );


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

