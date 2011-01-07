use strict;
use warnings;
use 5.010;

use Test::More;

########################################################
#                                                      #
# This test checks timeout handling in MCP::State.     #
# Please note that we can not test for the exact       #
# timeout value we expect because we do not know       #
# how much time has passed from the relevant           #
# timeout to start running and the time we check       #
# this timeout. Thus the test use $expect-1 <=$timeout # 
# and $timeout <= $expect.                             #
#                                                      #
########################################################


BEGIN{use_ok('Artemis::MCP::State')}

my $state = Artemis::MCP::State->new();
isa_ok($state, 'Artemis::MCP::State');

my $timeout_span = 1;


sub initial_state
{

        {'current_state' => 'started',
          'install' => {
                        'timeout_install_span' => 3*$timeout_span,
                        'timeout_boot_span'    => $timeout_span,
                        'timeout_current_date' => undef
                       },
                         'prcs' => [
                                    {
                                     'timeout_boot_span' => 7*$timeout_span,
                                     'timeout_current_date' => undef,
                                     'results' => [],
                                     'current_state' => 'preload'
                                    },
                                    {
                                     'timeout_testprograms_span' => [ 5, 2],
                                     'timeout_boot_span' => 2 * $timeout_span,
                                     'timeout_current_date' => undef,
                                     'results' => [],
                                     'current_state' => 'preload'
                                    },
                                    {
                                     'timeout_testprograms_span' => [ 10, 4],
                                     'timeout_boot_span' => 3 * $timeout_span,
                                     'timeout_current_date' => undef,
                                     'results' => [],
                                     'current_state' => 'preload'
                                    },
                                     {
                                      'timeout_testprograms_span' => [ 15, 6],
                                      'timeout_boot_span' => 4 * $timeout_span,
                                      'timeout_current_date' => undef,
                                      'results' => [],
                                      'current_state' => 'preload'
                                    }
                                   ],
                                     'results' => []
                             }
}

my ($retval, $timeout);
$retval = $state->state_init(initial_state());
is($retval, 0, 'Init succeeded');
$retval = $state->state_details->current_state();
is($retval, 'reboot_install', 'Current state at installation');

sleep 2;
($retval, $timeout) = $state->update_state();
is($state->testrun_finished, 1, 'Timeout detected');
is_deeply($state->state_details->results,
          [{
           'msg' => 'timeout hit while waiting for installer booting',
           'error' => 1,
          }],
          'Timeout added to results list');

my $expected_timeout;
my $start_time = time();
$retval = $state->state_init(initial_state());

# we expect timeout_install_span 
$expected_timeout = 3*$timeout_span-(time() - $start_time);
($retval, $timeout) = $state->update_state({state => 'start-install'});
ok(($expected_timeout - 1 <= $timeout   and $timeout <= $expected_timeout), 
   'Timeout returned after start-install within expected range');


# we timeout_boot_span of PRC0, no more than 
$expected_timeout = 7*$timeout_span-(time() - $start_time);
($retval, $timeout) = $state->update_state({state => 'end-install'});
ok(($expected_timeout - 1 <= $timeout   and $timeout <= $expected_timeout), 
   'Timeout returned after end-install within expected range');



# ($retval, $timeout) = $state->update_state({state => 'end-install'});
# is($retval, 0, 'end-install handled');
# $retval = $state->state_details->current_state();
# is($retval, 'reboot_test', 'Current state after installation');

# ($retval, $timeout) = $state->update_state({ state => 'start-guest', prc_number => 1});
# is($retval, 0, '1. guest_started handled');
# $retval = $state->state_details->current_state();
# is($retval, 'testing', 'Current state after 1. guest started');

# ($retval, $timeout) = $state->update_state({ state => 'start-guest', prc_number => 2});
# is($retval, 0, '2. guest_started handled');
# $retval = $state->state_details->current_state();
# is($retval, 'testing', 'Current state after 2. guest started');

# ($retval, $timeout) = $state->update_state({ state => 'start-guest', prc_number => 3});
# is($retval, 0, '3. guest_started handled');
# $retval = $state->state_details->current_state();
# is($retval, 'testing', 'Current state after 3. guest started');


# ($retval, $timeout) = $state->update_state({ state => 'start-testing', prc_number => 0});
# is($retval, 0, '3. guest_started handled');
# $retval = $state->state_details->current_state();
# is($retval, 'testing', 'Current state after 3. guest started');



done_testing();
