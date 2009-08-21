#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use aliased 'Artemis::MCP::Scheduler::Job';
use aliased 'Artemis::MCP::Scheduler::Host';
use aliased 'Artemis::MCP::Scheduler::Queue';
use aliased 'Artemis::MCP::Scheduler::Controller';
use aliased 'Artemis::MCP::Scheduler::TestRequest';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::Dummy';
use aliased 'Artemis::MCP::Scheduler::PreconditionProducer';
use aliased 'Artemis::MCP::Scheduler::OfficialHosts';
use aliased 'Artemis::MCP::Scheduler::OfficialQueues';

use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;

use Test::More tests => 6;

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_scheduling.yml' );
# -----------------------------------------------------------------------------------------------------------------

my @hostlist = @{ OfficialHosts->new->hostlist };

my $scheduler = Controller->new;
$scheduler->algorithm->queues(OfficialQueues->new->queuelist);
$scheduler->algorithm->queues->{Xen}->{testrequests} = [
                                                        TestRequest->new
                                                        (
                                                         queue              => 'Xen',
                                                         requested_features => ['Mem <= 8000'],
                                                        ),
                                                       ] ;

$scheduler->algorithm->queues->{KVM}{testrequests} = [
                                                      TestRequest->new
                                                      ( queue              => 'KVM',
                                                        requested_features => [ 'Mem <= 8000' ],
                                                      ),
                                                     ];
my $job = $scheduler->get_next_job(\@hostlist);

isa_ok($job, Job, 'Controller returns a job');
isa_ok($job->host, Host, 'Returned job has a host');
is($job->host->name, 'dickstone', 'Evaluation of feature list in a testrequest');

push @hostlist, Host->new
    (
     name => 'featureless',
     state => 'free'
    );

my $algorithm = Algorithm->new_with_traits ( traits => [Dummy] );

my $queue = Queue->new
    (
     name     => 'Xen',
     priority => 300,
     producer => PreconditionProducer->new,
     testrequests => [
                      TestRequest->new
                      (
                       requested_features => ['Mem <= 8000'],
                       queue => 'Xen',
                      )
                     ],
    );

my $request = TestRequest->new
    (
     hostnames => [ 'featureless' ],
     queue => 'Xen',
    );
unshift @{$queue->testrequests}, $request;

$algorithm->add_queue($queue);
$scheduler->algorithm($algorithm);

$job = $scheduler->get_next_job(\@hostlist);

isa_ok($job, Job, 'Scheduler returns a job');
isa_ok($job->host, Host, 'Returned job has a host');
is($job->host->name, 'featureless', 'Evaluation of feature list in a testrequest');

