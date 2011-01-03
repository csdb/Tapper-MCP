package Artemis::MCP::State::Details;

use 5.010;
use strict;
use warnings;

use Moose;

has state_details => (is => 'rw',
                      default => sub { {current_state => 'invalid'} }
                     );


=head1 NAME

Artemis::MCP::State::Details - Encapsulate state_details attribute of MCP::State

=head1 SYNOPSIS

 use Artemis::MCP::State::Details;
 my $state_details = Artemis::MCP::State::Details->new();
 $state_details->prc_results_add(0, {success => 0, mg => 'No success'});

=head1 FUNCTIONS


=head2 prc_results_add

Add a new results hash to one PRC

@return success - 0
@return error   - error string

=cut

=head2 state_init

Initialize the state or read it back from database.

@return success - 0
@return error   - error string

=cut

sub state_init
{
        my ($self, $data) = @_;
        $self->state_details($data);
        @{$self->state_details}{qw(current_state results)} = 
          ( 'reboot_install', [], );
        $self->state_details->{prcs} ||= [];
        foreach my $this_prc (@{$self->state_details->{prcs}}) {
                $this_prc->{results} ||= [];
        }
        my $install = $self->state_details->{install};
        $install->{timeout_current_date} = $install->{timeout_boot_span} + time();
        $self->commit();
        return 0;
}

=head2 current_state

Getter and setter for current state name.

@param  string - state name (optional)
@return string - state name

=cut

sub current_state
{
        my ($self, $state) = @_;
        $self->state_details->{current_state} = $state if defined $state;
        return $self->state_details->{current_state};
}


=head2 prc_boot_start

Sets timeouts for given PRC to the ones associated with booting of this
PRC started.

@param  int - PRC number

@return int - boot timeout span

=cut

sub prc_boot_start
{
        my ($self, $num) = @_;
        $self->state_details->{prcs}->[$num]->{timeout_current_date} = 
          time + $self->state_details->{prcs}->[$num]->{timeout_boot_span};
        return $self->state_details->{prcs}->[$num]->{timeout_boot_span};
}

=head2 prc_timeout_current_span

Get the current timeout date for given PRC

@param  int - PRC number

@return int - timeout date

=cut

sub prc_timeout_current_date
{
        my ($self, $num) = @_;
        return $self->state_details->{prcs}->[$num]->{timeout_current_date};
}


=head2 prc_results_add

Add a new message to results of given PRC

@param hash ref - containing success(bool) and msg(string)
@param int      - PRC number

=cut

sub prc_results_add
{
        my ($self, $num, $msg) = @_;
        push @{$self->state_details->{prcs}->[$num]->{results}}, $msg;
}       

=head2 prc_count

Return number of PRCs

@return int - number of PRCs

=cut

sub prc_count
{
        return int @{shift->state_details->{prcs}};
}


=head2 prc_state

Getter and setter for current state of given PRC.

@param  int    - PRC number
@param  string - state name (optional)

@return string - state name

=cut

sub prc_state
{
        my ($self, $num, $state) = @_;
        $self->state_details->{prcs}->[$num]{current_state} = $state if defined $state;
        return $self->state_details->{prcs}->[$num]{current_state};
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

=head2 start_install

Update timeouts for "installation started".

@return int - new timeout span

=cut

sub start_install
{
        my ($self) = @_;
        $self->state_details->{install}->{timeout_current_date} = 
          time + $self->state_details->{install}->{timeout_install_span};
        return $self->state_details->{install}->{timeout_install_span};
}

=head2 start_install

Update timeouts for "given PRC started booting".

@return int - new timeout span

=cut

sub prc_boot_start
{
        my ($self, $num) = @_;
        
        $self->state_details->{prcs}->[$num]->{timeout_current_date} = 
          time() + $self->state_details->{prcs}->[$num]->{timeout_boot_span};
        
        return $self->state_details->{prcs}->[$num]->{timeout_boot_span};
}


=head2 prc_next_timeout

Set next PRC timeout as current and return it as timeout span.

@param int - PRC number

@return int - next timeout span

=cut

sub prc_next_timeout
{
        my ($self, $num) = @_;
        my $prc = $self->state_details->{prcs}->[$num];
        my $next_timeout;
        given ($prc->state){
                when('preload') { $next_timeout = $prc->{timeout_boot_span}}
                when('boot')    {
                        if (ref $prc->{timeout_testprograms_span} eq 'ARRAY' and
                            @{$prc->{timeout_testprograms_span}}) {
                                $next_timeout = $prc->{timeout_testprograms_span}->[0];
                        } else {
                                $next_timeout  ||= 60; # one minute for "end-testing"
                        } 
                } 
                when('test')
        }
                
        $next_timeout = $self->state_details->{prcs}->[$num]->{timeout_testprograms_span}->[0];
        $self->state_details->{prcs}->[$num]->{timeout_current_date} = time() + $next_timeout;
        return $next_timeout;
}

=head2 prc_current_test_number

Get or set the number of the testprogram currently running in given PRC.

@param int - PRC number
@param int - test number (optional)


@return test running    - test number starting from 0
@return no test running - undef

=cut

sub prc_current_test_number
{
        my ($self, $num, $test_number) = @_;
        $self->state_details->{prcs}->{$num}{number_current_test} = $test_number 
          if defined $test_number;
        return $self->state_details->{prcs}->{$num}{number_current_test};
}

1;
