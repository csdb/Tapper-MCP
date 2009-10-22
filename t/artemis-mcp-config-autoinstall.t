#! /usr/bin/env perl

use strict;
use warnings;

use Test::Fixture::DBIC::Schema;
use YAML;

use Artemis::Schema::TestTools;

use Test::More;
use Test::Deep;
use Sys::Hostname;
use Socket;

BEGIN { use_ok('Artemis::MCP::Config'); }


# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_autoinstall.yml' );
# -----------------------------------------------------------------------------------------------------------------


my $producer = Artemis::MCP::Config->new(1);
isa_ok($producer, "Artemis::MCP::Config", 'Producer object created');

my $config = $producer->create_config();
is(ref($config),'HASH', 'Config created');


my $artemis_host = Sys::Hostname::hostname();
my $packed_ip    = gethostbyname($artemis_host);
fail("Can not get an IP address for artemis_host ($artemis_host): $!") if not defined $packed_ip;

my $artemis_ip   = inet_ntoa($packed_ip);

ok(defined $config->{installer_grub}, 'Grub for installer set');
is($config->{installer_grub}, 
   "title opensuse 11.2\n".
   "kernel /tftpboot/kernel autoyast=bare.cfg artemis_ip=$artemis_ip artemis_host=$artemis_host artemis_port=1337 artemis_environment=test\n".
   "initrd /tftpboot/initrd\n",
   'Expected value for installer grub config');

done_testing();
