package Artemis::MCP::State;

use 5.010;
use strict;
use warnings;

use Moose;
use List::Util qw/max min/;
use Perl6::Junction qw/any/;

use Artemis::MCP::State::Details;

has state_details => (is => 'rw',
                      default => sub { {current_state => 'invalid'} }
                     );
# needed for state comparison
has all_states    => (is => 'rw',
                      default => sub {
                              return
                              {
                               started        => 1,
                               reboot_install => 2,
                               installing     => 3,
                               reboot_test    => 4,
                               testing        => 5,
                               finished       => 6,
                              }});


sub BUILD
{
        my ($self) = @_;
        $self->state_details(Artemis::MCP::State::Details->new());
}

=head1 NAME

Artemis::MCP::State - Keep state information for one specific test run

=head1 SYNOPSIS

 use Artemis::MCP::State;
 my $state_handler = Artemis::MCP::State->new($testrun_id);
 my $state = $state_handler->get_current_state();
 $self->compare_given_state($state);

=head1 FUNCTIONS

=head2 is_msg_valid

Check whether received message is valid in current state.

@return valid   - 1
@return invalid - 0

=cut

sub is_msg_valid
{
        my ($self, $msg, $states, $prc_number) = @_;

        if (not $self->state_details->current_state eq any(@$states)){
                my $result =
                  ({
                    error => 1,
                    msg   => "Received $msg->{state} in state '".$self->state_details->current_state.
                    "'. This message is only allowed in states ".join(", ",@$states)
                   });

                $self->state_details->results({error => 1, msg => $result});
                if (defined $prc_number) {
                        $self->state_details->prc_results($prc_number, {error => 1, msg => $result});
                        $self->state_details->prc_state($prc_number, 'finished');

                        # if broken PRC is the first one, it may not start its guests
                        if ($self->state_details->is_all_prcs_finished() or $prc_number == 0) {
                                $self->state_details->current_state('finished');
                                return (0);
                        }
                } else {
                        $self->state_details->current_state('finished');
                        return(0);
                }
        }
        return(1);
}

=head2 compare_given_state

Compare the current state to a given state name. Return -1 if the given
state is earlier then the current, 1 if the current state is earlier
then the given one and 0 if both are equal.

@param string - state name

@return current state is earlier -  1
@return given   state is earlier - -1
@return states are equal         -  0

=cut

sub compare_given_state
{
        my ($self, $given_state) = @_;
        return $self->all_states->{$given_state} <=> $self->all_states->{$self->state_details->get_current_state};
}

=head2 get_current_timeout_span

Returns the time in seconds since the next timeout hits. When multiple
timeouts are currently running (during test with multiple PRCs) the
lowest of these timeouts is choosen. This value can be used for sleeping
in reads.

@return int - timeout span in seconds

=cut

sub get_current_timeout_span
{

}

=head2 state_init

Initialize the state or reload it from database.

@return success - 0
@return error   - error string

=cut

sub state_init
{
        my ($self, $data, $revive) = @_;
        if ($revive) {
                $self->state_details->reload();
        } else {
                $self->state_details->state_init($data);
        }
        return 0;
}

=head2 update_installer_timeout

Update the timeout during installation.

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub update_installer_timeout
{
        my ($self) = @_;
        my $now = time();
        my $installer_timeout_date = $self->state_details->installer_timeout_current_date;
        if ( $installer_timeout_date <= $now) {
                my $msg = 'timeout hit ';
                given ($self->state_details->current_state){
                        when ('started')        { $msg .= 'during preparation. Timeout was probably too low.'};
                        when ('reboot_install') { $msg .= 'while waiting for installer booting'};
                        when ('installing')     { $msg .= 'while waiting for installation'};
                }
                $self->state_details->results({error => 1, msg => $msg});
                $self->state_details->current_state('finished');
                return (1, undef);
        }
        return (0, $installer_timeout_date - $now);
}

=head2 update_prc_timeout

Check and update timeouts for one PRC.

@param hash ref - PRC

@return success - new timeout
@return error   - undef

=cut

sub update_prc_timeout
{
        my ($self, $prc) = @_;

        return undef;
}

=head2 update_test_timeout

Update timeouts during test phase.

=cut

sub update_test_timeout
{
        my ($self) = @_;
        my $now = time();

        if ($self->state_details->current_state ~~ 'reboot_test') {
                my $prc0_timeout = $self->state_details->prc_timeout_current_date(0);
                if ( $prc0_timeout <= $now) {
                        my $msg = 'Timeout while booting testmachine';
                        $self->state_details->prc_results(0, {error => 1, msg => $msg});
                        $self->state_details->results({error => 1, msg => $msg});
                        $self->state_details->current_state('finished');
                        return (1, undef);
                }
        }

        my $new_timeout=0;
        # we need the PRC number, thus not foreach
 PRC:
        for (my $i = 0; $i<= $self->state_details->prc_count; $i++) {
                given($self->state_details->prc_state($i)){
                        when ( any( 'finished', 'preload')) { next PRC }
                        when ('boot') {
                                if ($self->state_details->prc_timeout_current_date <= $now){
                                        my $msg = "Timeout while booting PRC$i";
                                        $self->state_details->results({error => 1, msg => $msg});
                                        $self->state_details->prc_results($i, {error => 1, msg => $msg});
                                        $self->state_details->prc_state($i, 'finished');
                                }}
                        when ('test') {
                                # $new_timeout = max($new_timeout,
                                #                    $self->update_prc_timeout());
                        }
                }
        }
}

=head2 update_timeouts

Update the timeouts in $self->state_details structure.

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub update_timeouts
{
        my ($self) = @_;
        given($self->state_details->current_state){
                when (any('started',
                          'reboot_install',
                          'installing')) { return $self->update_installer_timeout() }
                when (any('reboot_test',
                          'testing'))    { return $self->update_test_timeout() }
                when ('finished')        { return( 1, undef) } # no timeout handling when finished
                default                  {
                        my $msg = 'Invalid state ';
                        $msg   .= $self->state_details->current_state;
                        $msg   .= ' during update_timeouts';
                        $self->state_details->results({error => 1, msg => $msg});
                        $self->log->error($msg);
                }
        }
        return (1, undef);

}


=head2 msg_start_install

Handle message start-install

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_start_install
{
        my ($self, $msg) = @_;

        my $valid = $self->is_msg_valid($msg, ['reboot_install']);
        return (1, undef) if not $valid;

        $self->state_details->current_state('installing');
        return (0, $self->state_details->start_install);
}

=head2 msg_end_install

Handle message end-install

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_end_install
{
        my ($self, $msg) = @_;

        my $valid = $self->is_msg_valid($msg, ['installing']);
        return (1, undef) if not $valid;


        $self->state_details->current_state('reboot_test');
        return (0, $self->state_details->prc_boot_start(0));
}

=head2 msg_error_install

Handle message error-install

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_error_install
{
        my ($self, $msg) = @_;

        my $valid = $self->is_msg_valid($msg, ['installing']);
        return (1, undef) if not $valid;

        $self->state_details->results({ error => 1,
                                        msg   => "Installation failed: ".$msg->{error},
                                      });
        $self->state_details->current_state('finished');

        return (1, undef);
}

=head2 msg_error_guest

Handle message error-guest

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_error_guest
{
        my ($self, $msg) = @_;

        my $nr = $msg->{prc_number};
        my $valid = $self->is_msg_valid($msg, ['reboot_test', 'testing'], $msg->{prc_number});
        return (1, undef) unless $valid;

        $self->state_details->prc_state($nr, 'fail');
        $self->state_details->prc_results
          ( $nr, { error => 1,
                   msg   => "Starting guest failed: ".$msg->{error},
                 });

        if ($self->state_details->is_all_prcs_finished()) {
                $self->state_details->current_state('finished');
                return (1, undef);
        }

        return (0, $self->state_details->get_min_prc_timeout());
}


=head2 msg_start_guest

Handle message start-guest

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_start_guest
{
        my ($self, $msg) = @_;

        my $nr = $msg->{prc_number};
        my $valid = $self->is_msg_valid($msg, ['reboot_test', 'testing'], $nr);
        return (1, undef) unless $valid;

        $self->state_details->prc_state($nr, 'boot');
        $self->state_details->prc_boot_start($nr);

        $self->state_details->current_state('testing');
        return (0,  $self->state_details->get_min_prc_timeout());
}


=head2 msg_start_testing

Handle message start-testing

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_start_testing
{
        my ($self, $msg) = @_;

        my $nr = $msg->{prc_number};

        my $valid = $self->is_msg_valid($msg, ['reboot_test', 'testing'], $nr);
        return (1, undef) unless $valid;

        $self->state_details->prc_next_timeout($nr);
        $self->state_details->current_state('testing');
        $self->state_details->prc_state($nr, 'test');

        return (0,  $self->state_details->get_min_prc_timeout());
}


=head2 msg_end_testing

Handle message end-testing

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_end_testing
{
        my ($self, $msg) = @_;

        my $nr = $msg->{prc_number};

        my $valid = $self->is_msg_valid($msg, ['reboot_test', 'testing'], $nr);
        return (1, undef) unless $valid;

        $self->state_details->prc_state($nr, 'finished');
        my $result = {
                      error => 0,
                      msg   => "Testing finished in PRC ".$msg->{prc_number},
                     };

        $self->state_details->prc_results($nr, $result);
        $self->state_details->results($result);

        if ($self->state_details->is_all_prcs_finished()) {
                $self->state_details->current_state('finished');
                return (1, undef);
        }

        return (0,  $self->state_details->get_min_prc_timeout());
}



=head2 msg_end_testprogram

Handle message end-testprogram

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_end_testprogram
{
        my ($self, $msg) = @_;

        my $nr = $msg->{prc_number};

        my $valid = $self->is_msg_valid($msg, ['testing'], $nr);
        return (1, undef) unless $valid;

        my $current_test_number = $self->state_details->prc_current_test_number($nr);
        if ($msg->{testprogram} != $current_test_number) {
                my $result = {error => 1,
                              msg => "Invalid order of testprograms in PRC $nr. ".
                              "Expected $current_test_number, got $msg->{testprograms}"
                             };
                $self->state_details->prc_results($nr, $result);
                $self->state_details->results($nr, $result);
                $self->state_details->prc_current_test_number($nr, $msg->{testprogram});
        }


        $self->state_details->prc_next_timeout($nr);
        return (0, $self->state_details->get_min_prc_timeout());
}


=head2 msg_error_testprogram

Handle message error-testprogram

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_error_testprogram
{
        my ($self, $msg) = @_;

        my $nr = $msg->{prc_number};
        my $valid = $self->is_msg_valid($msg, ['testing'], $nr);
        return (1, undef) unless $valid;

        my $current_test_number = $self->state_details->prc_current_test_number($nr);
        if ($msg->{testprogram} != $current_test_number) {
                my $result = {error => 1,
                              msg => "Invalid order of testprograms in PRC $nr. ".
                              "Expected $current_test_number, got $msg->{testprograms}"
                             };
                $self->state_details->prc_results($nr, $result);
                $self->state_details->results($nr, $result);
                $self->state_details->prc_current_test_number($nr, $msg->{testprogram});
        }

        my $result = {error => 1,
                      msg => $msg->{error},
                     };
        $self->state_details->prc_results($nr, $result);
        $self->state_details->results($nr, $result);

        $self->state_details->prc_next_timeout($nr);
        return (0, $self->state_details->get_min_prc_timeout());
}

=head2 msg_reboot

Handle message reboot

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub msg_reboot
{
        my ($self, $msg) = @_;

        my $nr = $msg->{prc_number};
        my $valid = $self->is_msg_valid($msg, ['testing'], $nr);
        return (1, undef) unless $valid;


        my $result = {error => 0,
                      msg => "Host rebooted",
                     };
        $self->state_details->prc_results($nr, $result);
        $self->state_details->results($nr, $result);

        $self->state_details->prc_next_timeout($nr);
        return (0, $self->state_details->get_min_prc_timeout());
}



=head2

Update the state based on a message received from caller. The function
returns a timeout span value that is the lowest of all currently active
timeouts. The given message can be empty. In this case only timeouts are
checked and updated if needed.

@param hash ref - message

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub update_state
{
        my ($self, $msg) = @_;
        my ($error, $timeout_span);
        my $now = time();

        if ($msg and ref($msg) eq 'HASH') {
                given ($msg->{state}) {
                        when ('start-install')     { ($error, $timeout_span) = $self->msg_start_install($msg)     };
                        when ('end-install')       { ($error, $timeout_span) = $self->msg_end_install($msg)       };
                        when ('error-install')     { ($error, $timeout_span) = $self->msg_error_install($msg)     };
                        when ('start-guest')       { ($error, $timeout_span) = $self->msg_start_guest($msg)       };
                        when ('error-guest')       { ($error, $timeout_span) = $self->msg_error_guest($msg)       };
                        when ('start-testing')     { ($error, $timeout_span) = $self->msg_start_testing($msg)     };
                        when ('end-testing')       { ($error, $timeout_span) = $self->msg_end_testing($msg)       };
                        when ('error-testprogram') { ($error, $timeout_span) = $self->msg_error_testprogram($msg) };
                        when ('end-testprogram')   { ($error, $timeout_span) = $self->msg_end_testprogram($msg)   };
                        when ('reboot')            { ($error, $timeout_span) = $self->msg_reboot($msg)            };
                        # (TODO) add default
                }
        }
        return $self->update_timeouts();
}

=head2 testrun_finished

Tells caller whether the testrun is already finished or not.

@return TR     finished - 1
@return TR not finished - 0

=cut

sub testrun_finished
{
        shift->state_details->current_state eq 'finished' ? 1 : 0;
}



1;

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 BUGS

None.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

 perldoc Artemis


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: restrictive

