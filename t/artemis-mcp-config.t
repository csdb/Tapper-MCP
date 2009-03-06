#! /usr/bin/env perl

use strict;
use warnings;

use Test::Fixture::DBIC::Schema;
use YAML;

use Artemis::Schema::TestTools;

use Test::More tests => 6; 

BEGIN { use_ok('Artemis::MCP::Config'); }


# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_xenpreconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------


my $producer = Artemis::MCP::Config->new(2);
isa_ok($producer, "Artemis::MCP::Config", 'Producer object created');

my $config = $producer->create_config();
is(ref($config),'HASH', 'Config created');


is($config->{preconditions}->[0]->{image}, "suse/suse_sles10_64b_smp_raw.tar.gz", 'first precondition is root image');
is($config->{preconditions}->[8]->{artemis_package}, "artemisutils/opt-artemis64.tar.gz", 'setting opt-artemis package');


is($config->{installer_stop}, 1, 'installer_stop');


