use strict;
use warnings;
use 5.010;

#################################################
#                                               #
# This test contains a number of checks for the #
# function MCP::State::is_msg_valid()           #
#                                               #
#################################################

use Test::More;

BEGIN{use_ok('Artemis::MCP::State')}

my $state = Artemis::MCP::State->new();


my $timeout_span = 1;

sub initial_state
{

        {'current_state' => 'started',
          'install' => {
                        'timeout_install_span' => '7200',
                        'timeout_boot_span' => $timeout_span,
                        'timeout_current_date' => undef
                       },
                         'prcs' => [
                                    {
                                     'timeout_boot_span' => $timeout_span,
                                     'timeout_current_date' => undef,
                                     'results' => [],
                                     'current_state' => 'preload'
                                    },
                                    {
                                     'timeout_boot_span' => $timeout_span,
                                     'timeout_current_date' => undef,
                                     'results' => [],
                                     'current_state' => 'preload'
                                    },
                                    {
                                     'timeout_boot_span' => $timeout_span,
                                     'timeout_current_date' => undef,
                                     'results' => [],
                                     'current_state' => 'preload'
                                    },
                                     {
                                     'timeout_boot_span' => $timeout_span,
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
$retval = $state->is_msg_valid({state => 'start-install'}, ['reboot_install']);
is($retval, 1, 'Message valid');

$retval = $state->is_msg_valid({state => 'start-install'}, ['test']);
is($retval, 0, 'Invalid message detected');
ok($state->testrun_finished, 'Invalid message/testrun finished');

$state->state_details->current_state('reboot_install');
isnt($state->testrun_finished, 1, 'Reset current state');

$retval = $state->is_msg_valid({state => 'start-install'}, ['test', 'reboot_install']);
is($retval, 1, 'Message valid in last element of set of states');

$retval = $state->is_msg_valid({state => 'start-install'}, ['test'], 0);
is($retval, 1, 'Do not quit testrun at out-of-order message for PRC0');
is($state->state_details->prc_state(0), 'finished', 'PRC finished after out-of-order message');

done_testing();
