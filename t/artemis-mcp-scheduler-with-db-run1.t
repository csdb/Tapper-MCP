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
use aliased 'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm';
use aliased 'Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer';
use aliased 'Artemis::MCP::Scheduler::OfficialHosts';
use aliased 'Artemis::MCP::Scheduler::OfficialQueues';

use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;

use Test::More tests => 3;

# --------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_scheduling.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# --------------------------------------------------------------------------------

my $scheduler = Controller->new (algorithm => Algorithm->new_with_traits ( traits => [DummyAlgorithm] ));

my $job = $scheduler->get_next_job(\@hostlist);

isa_ok($job,         Job,         'Controller returns a job');
isa_ok($job->host,   Host,        'Returned job has a host');
is($job->host->name, 'dickstone', 'Evaluation of feature list in a testrequest');

push @hostlist, Host->new
    (
     name => 'featureless',
     state => 'free'
    );

my $algorithm = Algorithm->new_with_traits ( traits => [Dummy] );
$scheduler->algorithm($algorithm);

$job = $scheduler->get_next_job(\@hostlist);

isa_ok($job,         Job,           'Scheduler returns a job');
isa_ok($job->host,   Host,          'Returned job has a host');
is($job->host->name, 'featureless', 'Evaluation of feature list in a testrequest');

