use strict;
use warnings;
use 5.010;

use Test::More;

BEGIN{use_ok('Artemis::MCP::State')}

my $state = Artemis::MCP::State->new();
isa_ok($state, 'Artemis::MCP::State');

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



$retval = $state->state_init(initial_state());
($retval, $timeout) = $state->update_state({state => 'start-install'});
is($retval, 0, 'start-install handled');
$retval = $state->state_details->current_state();
is($retval, 'installing', 'Current state at installation');


($retval, $timeout) = $state->update_state({state => 'end-install'});
is($retval, 0, 'end-install handled');
$retval = $state->state_details->current_state();
is($retval, 'reboot_test', 'Current state after installation');

done_testing();
