use strict;
use warnings;
use 5.010;

use Test::More;
use Artemis::Schema::TestTools;
use Test::Fixture::DBIC::Schema;
use Artemis::Model 'model';

BEGIN{use_ok('Artemis::MCP::State')}

sub message_create
{
        my ($data) = @_;
        my $message = model('TestrunDB')->resultset('Message')->new
                  ({
                   message => $data,
                   testrun_id => 23,
                   });
        $message->insert;
        return $message;
}
        


# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------

my $initial_state = {
                     'current_state' => 'started',
                     'install' => {
                                   'timeout_install_span' => 3,
                                   'timeout_boot_span'    => 1,
                                   'timeout_current_date' => undef
                                  },
                     'prcs' => [
                                {
                                 'timeout_boot_span' => 7,
                                 'timeout_current_date' => undef,
                                 'results' => [],
                                 'current_state' => 'preload'
                                },
                                {
                                 'timeout_testprograms_span' => [ 5, 2],
                                 'timeout_boot_span' => 2,
                                 'timeout_current_date' => undef,
                                 'results' => [],
                                 'current_state' => 'preload'
                                },
                                {
                                 'timeout_testprograms_span' => [ 10, 4],
                                 'timeout_boot_span' => 3,
                                 'timeout_current_date' => undef,
                                 'results' => [],
                                 'current_state' => 'preload'
                                },
                                {
                                 'timeout_testprograms_span' => [ 15, 6],
                                 'timeout_boot_span' => 4,
                                 'timeout_current_date' => undef,
                                 'results' => [],
                                 'current_state' => 'preload'
                                }
                               ],
                     'results' => []
                    };


my ($retval, $timeout);

{
        my $state = Artemis::MCP::State->new(23);
        isa_ok($state, 'Artemis::MCP::State');
        
        $retval = $state->state_init($initial_state);
        ($retval, $timeout) = $state->update_state(message_create({state => 'takeoff'}));
        ($retval, $timeout) = $state->update_state(message_create({state => 'start-install'}));
        ($retval, $timeout) = $state->update_state(message_create({state => 'end-install'}));
        ($retval, $timeout) = $state->update_state(message_create({ state => 'start-guest', prc_number => 1}));
        ($retval, $timeout) = $state->update_state(message_create({ state => 'start-guest', prc_number => 2}));
        ($retval, $timeout) = $state->update_state(message_create({ state => 'start-guest', prc_number => 3}));
        ($retval, $timeout) = $state->update_state(message_create({ state => 'start-testing', prc_number => 0}));
        $retval = $state->state_details->current_state();
        is($retval, 'testing', 'Current state after 3. guest started');
        
}

{
        my $state = Artemis::MCP::State->new(23);
        isa_ok($state, 'Artemis::MCP::State');
        
        $retval = $state->state_init(undef, 1);
        is( $state->state_details->current_state, 'testing', 'State after revive');

}





done_testing();
