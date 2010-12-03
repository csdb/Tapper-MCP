#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 5;

BEGIN { use_ok( 'Artemis::MCP::Info' ); }


my $info = Artemis::MCP::Info->new();
isa_ok($info, 'Artemis::MCP::Info', 'Created object');


my $timeout = 10;
$info->add_prc(0, $timeout);
my $received = $info->get_boot_timeout(0);
is($received, $timeout, 'Add PRC and get its boot timeout');

$info->add_testprogram(3, {timeout => 20, name => "foo", argv => ['--bar']});
$info->add_testprogram(3, {timeout => 10, name => "foo", argv => ['--bar']});
$info->add_testprogram(3, {timeout =>  5, name => "foo", argv => ['--bar']});
$info->add_testprogram(3, {timeout => 30, name => "foo", argv => ['--bar']});
my @received_list = $info->get_testprogram_timeouts(3);
is_deeply(\@received_list, [20, 10, 5, 30], 'Setting and getting testprogram timeouts');
is($info->get_prc_count(), 3, 'Get PRC count');
use Data::Dumper;
print STDERR Dumper  $info->get_state_config();
