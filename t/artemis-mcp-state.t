use strict;
use warnings;

use Test::More;

BEGIN{use_ok('Artemis::MCP::State')}

my $state = Artemis::MCP::State->new();
isa_ok($state, 'Artemis::MCP::State');


my $initial_state = 
{
 'current_state' => 'started',
 'install' => {
               'timeout_install_span' => '7200',
               'timeout_boot_span' => '5',
               'timeout_current_date' => undef
              },
 'prcs' => [
            {
             'timeout_boot_span' => 10,
             'timeout_current_date' => undef,
             'results' => [],
             'state' => 'preload'
            },
            {
             'timeout_boot_span' => '5',
             'timeout_current_date' => undef,
             'results' => [],
             'state' => 'preload'
            },
            {
             'timeout_boot_span' => '5',
             'timeout_current_date' => undef,
             'results' => [],
             'state' => 'preload'
            },
            {
             'timeout_boot_span' => '5',
             'timeout_current_date' => undef,
             'results' => [],
             'state' => 'preload'
            }
           ],
 'results' => []
};


my $retval = $state->state_init($initial_state);
is($retval, 0, 'Init succeeded');
$retval = $state->get_current_state();
is($retval, 'reboot_install', 'Current state at installation');

my $timeout;

($retval, $timeout) = $state->update_state({state => 'start-install'});
is($retval, 0, 'start-install handled');
$retval = $state->get_current_state();
is($retval, 'installing', 'Current state at installation');


done_testing();
