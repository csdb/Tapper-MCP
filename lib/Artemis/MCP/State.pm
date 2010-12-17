package Artemis::MCP::State;

use 5.010;
use strict;
use warnings;

use Moose;
use List::Util qw/min/;

has state_details => (is => 'rw',
                              
                      default => sub { 
                              return => {current_state => 'invalid'}
                      }
                     );
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

=head1 NAME

Artemis::MCP::State - Keep state information for one specific test run

=head1 SYNOPSIS

 use Artemis::MCP::State;
 my $state_handler = Artemis::MCP::State->new($testrun_id);
 my $state = $state_handler->get_current_state();
 $self->compare_given_state($state);

=head1 FUNCTIONS


=head2 commit

Update database entry.

@return success - 0
@return error   - error string

=cut

sub commit
{
        my ($self) = @_;
        return 0;
}

=head2 get_current_state

Returns the name of the current state.

@return string - state name

=cut

sub get_current_state
{
         shift->state_details->{current_state};
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
        return $self->all_states->{$given_state} <=> $self->all_states($self->get_current_state);
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

Initialize the state or read it back from database.



@return success - 0
@return error   - error string

=cut

sub state_init
{
        my ($self, $data, $revive) = @_;
        if ($revive) {
        } else {
                $self->state_details($data);
                @{$self->state_details}{qw(current_state results)} = 
                  ( 'reboot_install', [], );
                $self->state_details->{prcs} ||= [];
                foreach my $this_prc (@{$self->state_details->{prcs}}) {
                        $this_prc->{results} ||= [];
                }
        }
        $self->commit();
        return 0;
}

=head2 update_timeouts

Update the timeouts in $self->state_details structure.

@return success - (0, timeout span for next state change)
@return error   - (1, undef)

=cut

sub update_timeouts
{

}

=head2 is_all_prcs_finished

Check whether all PRCs have finished already.

@param     all PRCs finished - 1
@param not all PRCs finished - 0

=cut

sub is_all_prcs_finished
{
        my ($self) = @_;
        # check whether this is the last PRC we are waiting for
        my $all_finished = 1;
        for ( my $i=0; $i = @{$self->state_details->{prcs}}; $i++) {
                if ($self->state_details->{prcs}->[$i]->{state} ne 'finished') {
                        $all_finished = 0;
                        last;
                }
        }
        return $all_finished;
}

=head2 get_min_prc_timeout

Check all PRCs and return the minimum of their upcoming timeouts in
seconds.

@return timeout span for the next state change during testing

=cut

sub get_min_prc_timeout
{
        my ($self) = @_;
        my $now = time();
        my $timeout = $self->state_details->{prcs}->[0]->{timeout_current_date} - $now;
        
        for ( my $i=1; $i = @{$self->state_details->{prcs}}; $i++) {
                next unless $self->state_details->{prcs}->[$i]->{timeout_current_date};
                $timeout = min($timeout, $self->state_details->{prcs}->[$i]->{timeout_current_date} - $now);
        }
        return $timeout;
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
        if ($self->state_details->{current_state} ne 'reboot_install'){
                push @{$self->state_details->{results}},
                {
                 error => 1,
                 msg   => "Received start-install in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in state reboot_install"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }
        
        $self->state_details->{current_state} = 'installing';
        $self->state_details->{install}->{timeout_current_date} = 
          time + $self->state_details->{install}->{timeout_install_span};
        return (0, $self->state_details->{install}->{timeout_install_span});
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
        if ($self->state_details->{current_state} ne 'installing'){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received end-install in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in state installing"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }
        
        $self->state_details->{current_state}                     = 'reboot_test';
        $self->state_details->{prcs}->[0]->{timeout_current_date} = 
          time + $self->state_details->{prcs}->[0]->{timeout_boot_span};
        return (0, $self->state_details->{prcs}->[0]->{timeout_boot_span});
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
        if ($self->state_details->{current_state} ne 'installing'){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received end-install in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in state installing"
                };
                $self->state_details->{current_state} = 'finished';
        }

        push @{$self->state_details->{results}}, 
        {
         error => 1,
         msg   => "Installation failed: ".$msg->{error},
        };
        $self->state_details->{current_state} = 'finished';
        
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
        if (($self->state_details->{current_state} ne 'reboot_test') and
            ($self->state_details->{current_state} ne 'testing')){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received error-guest in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in states testing and reboot_test "
                };
                $self->state_details->{current_state} = 'finished';
                return (1, undef);
        }

        push @{$self->state_details->{results}}, 
        {
         error => 1,
         msg   => "Starting PRC ".$msg->{prc_number}." failed: ".$msg->{error},
        };

        my $nr = $msg->{prc_number};
        delete $self->state->{prcs}->[$nr]->{timeout_current_date};
        $self->state->{prcs}->[$nr]->{state} = 'fail';
        push @{$self->state->{prcs}->[$nr]->{state}},
        {
         error => 1,
         msg   => "Starting guest failed: ".$msg->{error},
        };

        if ($self->is_all_prcs_finished()) {
                $self->state_details->{current_state} = 'finished';
                return (1, undef);
        }

        my $timeout = $self->get_min_prc_timeout();
        return (0, $timeout);
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

        if (($self->state_details->{current_state} ne 'reboot_test') and
            ($self->state_details->{current_state} ne 'testing')){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received start-guest in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in states reboot_test or testing"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }


        my $nr = $msg->{prc_number};
        $self->state->{prcs}->[$nr]->{state} = 'boot';
        $self->state->{prcs}->[$nr]->{timeout_current_date} = 
          time() + $self->state->{prcs}->[$nr]->{timeout_boot_span};

        my $timeout = $self->get_min_prc_timeout();
        
        $self->state_details->{current_state} = 'testing';
        return (0,  $timeout);
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

        if (($self->state_details->{current_state} ne 'reboot_test') and
            ($self->state_details->{current_state} ne 'testing')){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received start-testing in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in states reboot_test or testing"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }

        my $nr = $msg->{prc_number};

        my $next_timeout = $self->state->{prcs}->[$nr]->{timeout_testprograms_span}->[0];
        $next_timeout  ||= 60; # one minute for "end-testing"
        $self->state->{prcs}->[$nr]->{timeout_current_date} = time() + $next_timeout;

        my $timeout = $self->get_min_prc_timeout();
        
        $self->state_details->{current_state} = 'testing';
        $self->state->{prcs}->[$nr]->{state} = 'test';
        return (0,  $timeout);
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

        if (($self->state_details->{current_state} ne 'reboot_test') and
            ($self->state_details->{current_state} ne 'testing')){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received start-testing in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in states reboot_test or testing"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }

        my $nr = $msg->{prc_number};
        delete $self->state->{prcs}->[$nr]->{timeout_current_date};
        $self->state->{prcs}->[$nr]->{state} = 'finished';

        push @{$self->state->{prcs}->[$nr]->{state}},
        {
         error => 0,
         msg   => "Testing finished in PRC ".$msg->{prc_number},
        };

        if ($self->is_all_prcs_finished()) {
                $self->state_details->{current_state} = 'finished';
                return (1, undef);
        }
        my $timeout = $self->get_min_prc_timeout();
        
        return (0,  $timeout);
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

        if ($self->state_details->{current_state} ne 'testing'){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received end-testprogram in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in states testing"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }

        my $nr = $msg->{prc_number};

        my $next_timeout = $self->state->{prcs}->[$nr]->{timeout_testprograms_span}->[$msg->{testprogram}+1];
        $next_timeout  ||= 60; # one minute for "end-testing"
        $self->state->{prcs}->[$nr]->{timeout_current_date} = time() + $next_timeout;


        my $timeout = $self->get_min_prc_timeout();
        return (0,  $timeout);
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

        if ($self->state_details->{current_state} ne 'testing'){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received error-testprogram in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in states testing"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }

        my $nr = $msg->{prc_number};

        my $next_timeout = $self->state->{prcs}->[$nr]->{timeout_testprograms_span}->[$msg->{testprogram}+1];
        $next_timeout  ||= 60; # one minute for "end-testing"
        $self->state->{prcs}->[$nr]->{timeout_current_date} = time() + $next_timeout;

        my $timeout = $self->get_min_prc_timeout();
       
        return (0,  $timeout);
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

        if ($self->state_details->{current_state} ne 'testing'){
                push @{$self->state_details->{results}}, 
                {
                 error => 1,
                 msg   => "Received error-testprogram in state '".$self->state_details->{current_state}.
                 "'. This message is only allowed in states testing"
                };
                $self->state_details->{current_state} = 'finished';
                return (1,undef);
        }

        my $nr = $msg->{prc_number};

        my $next_timeout = $self->state->{prcs}->[$nr]->{timeout_testprograms_span}->[$msg->{testprogram}+1];
        $next_timeout  ||= 60; # one minute for "end-testing"
        $self->state->{prcs}->[$nr]->{timeout_current_date} = time() + $next_timeout;

        my $timeout = $self->get_min_prc_timeout();
       
        return (0,  $timeout);
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

       #  $self->state_details =
       #  { 
       #    current_state => (started|reboot_install|installing|reboot_test|testing|finished|)
       #    results => [
       #      {success => 1, msg => "Testprogram 0 in PRC 0 finished", },
       #      {success => 0, msg => "Failed to boot PRC 2 after 1200 seconds", },
       #      {success => 0, msg => "Testprogram 0 in PRC 0 not finished after 1200 seconds", },
       #    ],
       #    install => {
       #    boot_timeout_span    => 1800,
       #    timeout_install_span => 800,
       #    timeout_current_date => 14524510,
       #    },
       #    prcs    => 
       #  [{ timeout_testprograms_span => [ 10, 15, 5, 17],
       #     timeout_current_date      =>  14524514,
       #     number_current_test       =>  2,
       #     state =>  'testing',
       #     results => [{success => 1, msg => undef, },
       #                 {success => 0, msg => 'Timeout reached', }],
       #     timeout_boot_span => 1800,
       #   },
       #   { timeout_testprograms_span => [ 100, 3],
       #     timeout_current_date      =>  14524523,
       #     number_current_test       =>  undef,
       #     state =>  'boot',
       #     results => undef,
       #     timeout_boot_span => 1200,
       #   },
       #   { timeout_testprograms_span => [ 100,3],
       #     timeout_current_date =>  undef,
       #     number_current_test =>  undef,
       #     state =>  'fail',
       #     results => [{success => 'FAIL', msg => 'Boot timeout reached', },
       #                ],
       #     timeout_boot_span => 1200,
       #   },
       #  ]
       # }


        return ($timeout_span);
}

=head2 testrun_finished

Tells caller whether the testrun is already finished or not.

@return TR     finished - 1
@return TR not finished - 0

=cut

sub testrun_finished
{
        shift->state_details->{current_state} eq 'finished' ? 1 : 0;
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

