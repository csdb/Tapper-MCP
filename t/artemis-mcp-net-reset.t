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

# pm211mip config
SKIP: {
        skip "Set env ARTEMIS_TEST_PM211MIP to test the PM211MIP plugin", 2 if !$ENV {ARTEMIS_TEST_PM211MIP};
        $srv->cfg->{reset_plugin} = 'PM211MIP';
        $srv->cfg->{reset_plugin_options} = {
                                             ip       => '192.168.1.39',
                                             user     => 'admin',
                                             passwd   => 'admin',
                                             outletnr => {
                                                          johnconnor  => 1,
                                                          sarahconnor => 2,
                                                         },
                                            };
        $ret = $srv->reboot_system ("johnconnor",  1);
        is($ret, 0, "Run PM211MIP reset plugin for johnconnor");
        $ret = $srv->reboot_system ("sarahconnor", 1);
        is($ret, 0, "Run PM211MIP reset plugin for sarahconnor");
}

done_testing;
