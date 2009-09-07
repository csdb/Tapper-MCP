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

use Test::More tests => 9;

# --------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_scheduling_run1.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# --------------------------------------------------------------------------------

my @initial_hostlist = @{ OfficialHosts->new->hostlist };

my $algorithm = Algorithm->new_with_traits ( traits => [DummyAlgorithm] );
my $scheduler = Controller->new (algorithm => $algorithm);


# Remember:
#   DummyAlgorithm sorts queues alphanumericaly by name:
#   KVM -> Kernel -> Xen

my @hostlist = @initial_hostlist;

# loop: {host_became_free
# busy wait: do { nothing() } until ($scheduler->new_testrun or $mcp->host_became_free);
my $job = $scheduler->get_next_job(\@hostlist);
# }

is( $scheduler->get_next_job()->shortname, "bbb-kvm",     "bbb-kvm");
is( $scheduler->get_next_job()->shortname, "ccc-kernel",  "ccc-kernel");
is( $scheduler->get_next_job()->shortname, "aaa-xen",     "aaa-xen");
is( $scheduler->get_next_job()->shortname, "bbb2-kvm",    "bbb2-kvm");
is( $scheduler->get_next_job()->shortname, "ccc2-kernel", "ccc2-kernel");
is( $scheduler->get_next_job()->shortname, "aaa2-xen",    "aaa2-xen");
is( $scheduler->get_next_job()->shortname, "bbb3-kvm",    "bbb3-kvm");
is( $scheduler->get_next_job()->shortname, "ccc3-kernel", "ccc3-kernel");
is( $scheduler->get_next_job()->shortname, "aaa3-xen",    "aaa3-xen");

