#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;

BEGIN { use_ok( 'Tapper::MCP::Info' ); }


my $info = Tapper::MCP::Info->new();
isa_ok($info, 'Tapper::MCP::Info', 'Created object');


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
my $state = $info->get_state_config();
is(@{$state->{prcs}}, 4, 'All PRCs handled in state_config');
is_deeply($state->{prcs}->[3]->{timeout_testprograms_span}, [ 20, 10, 5, 30 ], 'Testprogram timeouts given');
