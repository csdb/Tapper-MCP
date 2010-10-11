#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Artemis::MCP::Net'); }

my $srv = Artemis::MCP::Net->new;

my $ret = $srv->reboot_system ("zomtec", 1);

is($ret, "zomtec-hello-reset", "Ran test reset plugin");

done_testing;
