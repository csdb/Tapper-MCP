#!/usr/bin/env perl

use strict;
use warnings;

use Class::C3;
use MRO::Compat;

use IO::Socket::INET;
use Log::Log4perl;
use POSIX ":sys_wait_h";
use Test::Fixture::DBIC::Schema;
use String::Diff;
use Sys::Hostname;
use YAML::Syck;
use Cwd;
use TAP::DOM;

use Artemis::MCP; # for $VERSION
use Artemis::MCP::Net;
use Artemis::Schema::TestTools;

use Test::More;
use Test::Deep;

BEGIN { use_ok('Artemis::MCP::Net'); }

my $hw_send_testrun_id=23;

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------

# (XXX) need to find a way to include log4perl into tests to make sure no
# errors reported through this framework are missed
my $string = "
log4perl.rootLogger                               = INFO, root
log4perl.appender.root                            = Log::Log4perl::Appender::Screen
log4perl.appender.root.layout                     = SimpleLayout";
Log::Log4perl->init(\$string);

my $srv = Artemis::MCP::Net->new;



SKIP:{
        skip "since environment variable ARTEMIS_RUN_CONSERVER_TEST is not set", 1 unless $ENV{ARTEMIS_RUN_CONSERVER_TEST};
        my $console = $srv->conserver_connect('bullock');
        isa_ok($console, 'IO::Socket::INET','Console connected');
        $srv->conserver_disconnect($console);
}



my ($error, $report) = $srv->hw_report_create($hw_send_testrun_id);

is ($error, 0, 'Successfull creation of hw_report');
is($report, "
TAP Version 13
1..2
# Artemis-Reportgroup-Testrun: 23
# Artemis-Suite-Name: Hardwaredb Overview
# Artemis-Suite-Version: $Artemis::MCP::VERSION
# Artemis-Machine-Name: dickstone
ok 1 - Getting hardware information
  ---
  cores: 2
  keyword: server
  mem: 4096
  vendor: AMD
  ...

ok 2 - Sending
", 'Hardware report layout');


done_testing();
