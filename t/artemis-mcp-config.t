#! /usr/bin/env perl

use strict;
use warnings;

use Test::Fixture::DBIC::Schema;
use YAML;

use Artemis::Schema::TestTools;

use Test::More tests => 14;
use Test::Deep;

BEGIN { use_ok('Artemis::MCP::Config'); }


# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_xenpreconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------


my $producer = Artemis::MCP::Config->new(2);
isa_ok($producer, "Artemis::MCP::Config", 'Producer object created');

my $config = $producer->create_config();
is(ref($config),'HASH', 'Config created');


is($config->{preconditions}->[0]->{image}, "suse/suse_sles10_64b_smp_raw.tar.gz", 'first precondition is root image');
is($config->{preconditions}->[4]->{filename}, "artemisutils/opt-artemis64.tar.gz", 'setting opt-artemis package for Dom0');
is($config->{preconditions}->[8]->{artemis_package}, "artemisutils/opt-artemis64.tar.gz", 'setting opt-artemis package for guest');
is($config->{preconditions}->[10]->{config}->{guests}->[0]->{exec}, "/usr/share/artemis/packages/mhentsc3/startkvm.pl", 'Setting guest start script in main PRC');

is($config->{installer_stop}, 1, 'installer_stop');



my $info = $producer->get_mcp_info();
isa_ok($info, 'Artemis::MCP::Info', 'mcp_info');
my @timeout = $info->get_testprogram_timeouts(1);
is_deeply(\@timeout,[15],'Timeout for testprogram in PRC 1');

$producer = Artemis::MCP::Config->new(3);
$config = $producer->create_config();
is(ref($config),'HASH', 'Config created');
is($config->{preconditions}->[3]->{config}->{max_reboot}, 2, 'Reboot test');

$info = $producer->get_mcp_info();
isa_ok($info, 'Artemis::MCP::Info', 'mcp_info');
my $timeout = $info->get_boot_timeout(0);
is($timeout, 5, 'Timeout booting PRC 0');
