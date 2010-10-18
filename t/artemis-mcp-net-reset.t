#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Log::Log4perl;

BEGIN { use_ok('Artemis::MCP::Net'); }

# (XXX) need to find a way to include log4perl into tests to make sure
# no errors reported through this framework are missed
my $string = "
log4perl.rootLogger                               = INFO, root
log4perl.appender.root                            = Log::Log4perl::Appender::Screen
log4perl.appender.root.layout                     = SimpleLayout";
Log::Log4perl->init(\$string);

my $srv = Artemis::MCP::Net->new;
my $ret = $srv->reboot_system ("zomtec", 1);
is($ret, "zomtec-hello-reset", "Run test reset plugin");

is($ret, "zomtec-hello-reset", "Ran test reset plugin");

done_testing;
