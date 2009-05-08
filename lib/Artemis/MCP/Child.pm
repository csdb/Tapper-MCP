package Artemis::MCP::Child;

use 5.010;
use strict;
use warnings;

use IO::Select;
use IO::Socket::INET;
use List::Util qw(min max);
use Moose;
use UNIVERSAL qw (can);
use YAML::Syck;

use Artemis::MCP::Net;
use Artemis::MCP::Config;

use constant BUFLEN => 1024;


extends 'Artemis::MCP::Control';

our $ONE_MINUTE=60;

=head1 NAME

Artemis::MCP::Child - Control one specific testrun on MCP side

=head1 SYNOPSIS

 use Artemis::MCP::Child;
 my $client = Artemis::MCP::Child->new($testrun_id);
 $child->runtest_handling($system);


=head1 FUNCTIONS


=head2 net_read_do

Put worker part of net_read into a sub so we can call it with accepted socket
as well as with readl file handle.

@param file handle - read from this socket
@param int         - timeout in seconds

@return success - message string read from remote)
@return timeout - 0

=cut

sub net_read_do
{
        my ($self, $fh, $timeout) = @_;
        my $msg;
        my $timeout_calc = $timeout;
        my $select = IO::Select->new() or return undef;
        $select->add($fh);
        
 NETREAD:
        while (1) {
                my $time   = time();
                my @ready;
                # if no timeout is given, it's ok to wait forever
                if ($timeout) {
                         @ready  = $select->can_read($timeout_calc);
                } else {
                         @ready  = $select->can_read();
                }
                $timeout_calc -= time() - $time;
                return 0 if not @ready;
                my $tmp;
                my $readbytes = sysread($fh, $tmp, BUFLEN);
                last NETREAD if not $readbytes;
                $msg     .= $tmp;
        }
        return $msg;
}

=head2 net_read

Reads new message from network socket. 

This function can be mocked when
testing allowing messages to come from a file during tests.

@param file handle - read from this socket
@param int         - timeout in seconds

@return hash reference

=cut

sub net_read
{
        my ($self, $fh, $timeout) = @_;
        my $msg;
        my $sock;

        if ($fh->can('accept')) {
                eval{
                        local $SIG{ALRM}=sub{die 'Timeout'};
                        alarm($timeout);
                        $sock = $fh->accept();
                };
                alarm(0);
                return {timeout => $timeout, error => 1} if $@=~m/Timeout/;
                $msg = $self->net_read_do($sock, $timeout);
        }
        else {
                $msg = $self->net_read_do($fh, $timeout);
        }
        return {timeout => $timeout, error => 1} if not $msg;
        my $yaml = Load($msg);
        return $yaml;

}


=head2 get_message

Read a message from socket.

@param file descriptor - read from this socket

@return success - hash reference containing received information
@return timeout - hash reference with timeout set to given timeout
@return error   - error string



=cut 

sub get_message
{
        my ($self, $fh, $timeout) = @_;
        my $msg = $self->net_read($fh, $timeout);
        return "Invalid status message format received from remote" if not ref $msg eq 'HASH';

        return $msg;
}

=head2 set_prc_state

Set timeouts in prc state array.

@return success - array ref to prc state array
@return error   - error string

=cut

sub set_prc_state
{
        my ($self, $mcp_info) = @_;
        my $prc_count = $mcp_info->get_prc_count();
        my $prc_state;
        for (my $i=0; $i<=$prc_count; $i++) {
                my $max_reboot = $mcp_info->get_max_reboot($i);
                $prc_state->[$i]->{max_reboot} = $max_reboot if $max_reboot;
                $prc_state->[$i]->{start} = $mcp_info->get_boot_timeout($i);
                push @{$prc_state->[$i]->{timeouts}}, $mcp_info->get_testprogram_timeouts($i);
                $prc_state->[$i]->{end} =  $ONE_MINUTE;   # give one minute for PRC to settle (i.e. time between sending start and end without any test)
        }
        return $prc_state;
}

=head2 wait_for_systeminstaller

Wait for state messages of System Installer and apply timeout on
booting to make sure we react on a system that is stuck while booting
into system installer. The time needed to install a system can vary
widely thus no timeout for installation is applied.

@param file handle - read from this file handle


@return success - 0
@return error   - error string

=cut 

sub wait_for_systeminstaller
{
        my ($self,$fh) = @_;

        my $timeout = $self->cfg->{times}{boot_timeout} || 0;
        
        my $msg = $self->get_message($fh, $timeout);
        return $msg if not ref($msg) eq 'HASH';
        return "Failed to boot Installer after timeout of $msg->{timeout} seconds" if $msg->{timeout};
        
        if (not $msg->{state} eq "start-install") {
                return qq(MCP expected state start-install but remote system is in state $msg->{state});
        }
        $self->log->debug("Installation started for testrun ".$self->testrun);

        $msg=$self->get_message($fh, 0);
        return $msg if not ref($msg) eq 'HASH';

        if ($msg->{state} eq 'end-install') {
                $self->log->debug("Installation finished for testrun ".$self->testrun);
                return 0;
        } elsif ($msg->{state} eq 'error-install') {
                return $msg->{error};
        } else {
                return  qq(MCP expected state end-install or error-install but remote system is in state "$msg->{state}");
        }
}


=head2 time_reduce

Reduce remaining timeout time for all guests by the time we slept in
select. If the remaining timeout for on PRC is less then the elapsed time, an
error message is put into the array and the number of PRC to start and stop is
reduced accordingly.

@param int       - time slept in select
@param array ref - states of all guests
@param int       - number of PRCs to start
@param int       - number of PRCs to stop

@returnlist - new values for (timeout, guest states, number of PRCs to start, new number of PRCs to stop)

=cut

sub time_reduce
{
        my ($self, $elapsed, $prc_state, $to_start, $to_stop) = @_;
        my $test_timeout;
        my $boot_timeout;

 PRC:
        for (my $i=0; $i<=$#{$prc_state}; $i++) {
                my $result;
                if ($prc_state->[$i]->{start} != 0) {
                        if (($prc_state->[$i]->{start} - $elapsed) <= 0) {
                                $prc_state->[$i]->{start} = 0;
                                delete $prc_state->[$i]->{timeouts};
                                $prc_state->[$i]->{end}   = 0;
                                $result->{error} = 1;
                                if ($prc_state->[$i]->{max_reboot}) {
                                        $result->{msg} = "reboot-test-summary\n   ---\n   got:";
                                        $result->{msg}.= $prc_state->[$i]->{count} || "0";
                                        $result->{msg}.= "\n   expected:$prc_state->[$i]->{max_reboot}\n   ...";
                                } else {
                                        $result->{msg} = "Guest $i: booting not finished in time, timeout reached";
                                }
                                $to_start--;
                                $to_stop--;
                                push @{$prc_state->[$i]->{results}}, $result;
                                next PRC;
                        } else {
                                $prc_state->[$i]->{start}= $prc_state->[$i]->{start} - $elapsed;
                        }
                        $boot_timeout = $prc_state->[$i]->{start} if not defined($boot_timeout);
                        $boot_timeout = min($boot_timeout, $prc_state->[$i]->{start});

                } elsif ($prc_state->[$i]->{timeouts}->[0]) {
                        if (($prc_state->[$i]->{timeouts}->[0] - $elapsed) <= 0) {
                                pop @{$prc_state->[$i]->{timeouts}};
                                $result->{error} = 1;
                                $result->{msg}   = "Host: Testing not finished in time, timeout reached";
                                # avoid another if/then/else, simply overwrite error for guests
                                $result->{msg}   = "Guest $i: Testing not finished in time, timeout reached" if $i != 0;
                                push @{$prc_state->[$i]->{results}}, $result;
                                next PRC;
                        } else {
                                $prc_state->[$i]->{timeouts}->[0] -= $elapsed;
                        }
                } elsif ($prc_state->[$i]->{end} != 0) {
                        if (($prc_state->[$i]->{end} - $elapsed) <= 0) {
                                $prc_state->[$i]->{end} = 0;
                                delete $prc_state->[$i]->{timeouts};
                                $result->{error} = 1;
                                $result->{msg}   = "Host: Testing not finished in time, timeout reached";
                                # avoid another if/then/else, simply overwrite error for guests
                                $result->{msg}   = "Guest $i: Testing not finished in time, timeout reached" if $i != 0;
                                push @{$prc_state->[$i]->{results}}, $result;
                                $to_stop--;
                                next PRC;
                        } else {
                                $prc_state->[$i]->{end} -= $elapsed;
                        }

                }
                
                my $newtimeout = $prc_state->[$i]->{end};
                $newtimeout    = $prc_state->[$i]->{timeouts}->[0] if $prc_state->[$i]->{timeouts}->[0];
                $test_timeout  = $newtimeout if not defined($test_timeout);
                $test_timeout  = min($test_timeout, $newtimeout)
        }
        return ($boot_timeout, $prc_state, $to_start, $to_stop) if $boot_timeout;
        no warnings 'uninitialized'; # if all loop cycles lead to timeouts, $test_timeout might be uninitialized
        return (max(1,$test_timeout), $prc_state, $to_start, $to_stop);

}

=head2 

Update PRC state array based on the received message.

@param hash ref  - message received
@param array ref - states of all guests
@param int       - number of PRCs to start
@param int       - number of PRCs to stop

@returnlist - new values for (timeout, guest states, number of PRCs to start, new number of PRCs to stop)

=cut

sub update_prc_state
{
        my ($self, $msg, $prc_state, $to_start, $to_stop) = @_;
        my $number = $msg->{prc_number}; # just to make the code shorter
        my $result;
        $result->{error} = 0;

        given($msg->{state}){
                when ('start-testing') {
                        $prc_state->[$number]->{start} = 0;
                        $result->{msg} = "Test in guest $number started" if $number != 0;
                        $result->{msg} = "Test in PRC 0 started" if $number == 0;
                        $to_start--;
                        push (@{$prc_state->[$number]->{results}}, $result);
                } 
                when ('end-testing') {
                        $prc_state->[$number]->{end} = 0;
                        if ($prc_state->[$number]->{max_reboot}) {
                                if ($prc_state->[$number]->{max_reboot} > $prc_state->[$number]->{count}) {
                                        for (my $i = $prc_state->[$number]->{count}+1; $i <= $prc_state->[$number]->{max_reboot}; $i++) {
                                                my $local_result;
                                                $local_result->{error} = 1;
                                                $local_result->{msg}   = "Reboot $i";
                                                push (@{$prc_state->[$number]->{results}}, $local_result);
                                        }
                                }
                        }
                        $result->{msg} = "Test in PRC 0 finished" if $number == 0;
                        $result->{msg} = "Test in guest $number finished" if $number != 0;
                        push (@{$prc_state->[$number]->{results}}, $result);
                        $to_stop--;
                }
                when ('error-testprogram') {
                        pop @{$prc_state->[$number]->{timeouts}};
                        $result->{error}             = $msg->{error};
                        $result->{msg}               = "Error in guest $number: $msg->{error}" if $number != 0;;
                        $result->{msg}               = "Error in PRC 0: $msg->{error}" if $number == 0;
                        $to_stop--;
                        push (@{$prc_state->[$number]->{results}}, $result);

                }
                when ('end-testprogram') {
                        shift @{$prc_state->[$number]->{testprograms}};
                        $result->{msg} = "Testprogram $msg->{program} in guest $number" if $number != 0;
                        $result->{msg} = "Testprogram $msg->{program} in PRC 0" if $number == 0;
                        push (@{$prc_state->[$number]->{results}}, $result);
                }
                when ('reboot') {
                        $prc_state->[$number]->{count} = $msg->{count};
                        if (not $msg->{max_reboot} eq $prc_state->[$number]->{max_reboot}) {
                                $self->log->warning("Got a new max_reboot count for PRC $number. Old value was $prc_state->[$number]->{max_reboot} ",
                                                    "new value is $msg->{max_reboot}. I continue with new value");
                                $prc_state->[$number]->{max_reboot} = $msg->{max_reboot};
                        }
                        $result->{msg} = "Reboot $msg->{count}";
                        push (@{$prc_state->[$number]->{results}}, $result);

                }
                default {
                        $self->log->error("Unknown state $msg->{state} for PRC $msg->{prc_number}");
                }
        }
        return ($prc_state, $to_start, $to_stop);
}

=head2 wait_for_testrun

Wait for start and end of a test program. Put start and end time into
database. The function also recognises errors send from the PRC. It returns an
array that can be handed over to tap_report_send. Optional file handle is used
for easier testing.

@param int - testrun id
@param file handle - read from this handle

@return reference to report array

=cut

sub wait_for_testrun
{
        my ($self, $fh, $mcp_info) = @_;
      
        my $prc_state = $self->set_prc_state($mcp_info);
        my $to_start   = scalar @$prc_state;  
        my $to_stop    = $to_start;

        my $timeout = $self->cfg->{times}{boot_timeout};

        # currently reboot not for virt guests
        $prc_state->[0]->{max_reboot} = $mcp_info->{max_reboot} if $mcp_info->{max_reboot};

        my $msg     = $self->get_message($fh, $timeout);
        return [{error=> 1, msg => $msg}] if not ref($msg) eq 'HASH';
        return [{error=> 1, msg => "Failed to boot test machine after timeout of $msg->{timeout} seconds"}] if $msg->{timeout};
        ($prc_state, $to_start, $to_stop) = $self->update_prc_state($msg, $prc_state, $to_start, $to_stop);

 MESSAGE:
        while ($to_stop) {
                my $lastrun = time();
                $msg=$self->get_message($fh, $timeout);
                return $msg if not ref($msg) eq 'HASH';
                
                if (not $msg->{timeout}) {
                        $self->log->debug(qq(state $msg->{state} in PRC $msg->{prc_number}, last PRC is $#$prc_state));
                        ($prc_state, $to_start, $to_stop) = $self->update_prc_state($msg, $prc_state, $to_start, $to_stop);
                }
                last MESSAGE if $to_stop <= 0;
                ($timeout, $prc_state, $to_start, $to_stop) = $self->time_reduce(time() - $lastrun, $prc_state, $to_start, $to_stop)
        }
        my @report_array;
        for (my $i = 0; $i <= $#{$prc_state}; $i++) {
                push @report_array, @{$prc_state->[$i]->{results}};
        }
        return \@report_array;
}


=head2 install

Install all packages and images for a given testrun. 

@param string      - system name
@param file handle - read from this file handle

@return success - 0
@return error   - error string

=cut

sub install
{
        my ($self, $hostname, $fh) = @_;
        my $retval;
     
        my $remote = new Artemis::MCP::Net;
        $self->log->debug("Write grub file for $hostname");
        $retval    = $remote->write_grub_file($hostname);
        return $retval if $retval;


        $self->log->debug("rebooting $hostname");
        $retval = $remote->reboot_system($hostname);
        return $retval if $retval;
        return 0;


}


=head2 runtest_handling

Start testrun and wait for completion.

@param string - system name

@return success - 0
@return error   - error string

=cut

sub runtest_handling
{

        my  ($self, $system) = @_;
        my $retval;
        
        my $srv=IO::Socket::INET->new(Listen=>5, Proto => 'tcp');
        return("Can't open socket for testrun $self->{testrun}:$!") if not $srv;


        my $producer = Artemis::MCP::Config->new($self->testrun);
        my $net      = Artemis::MCP::Net->new();

        $self->log->debug("Create install config for $system");
        my $config                 = $producer->create_config();
        return $config if not ref($config) eq 'HASH';
        my $mcp_info = $producer->get_mcp_info();

        # check if $srv really knows sockport(), because in case of a test
        # IO::Socket::INET is overwritten to read from a file
        $config->{mcp_port}        = 0;
        $config->{mcp_port}        = $srv->sockport if $srv->can('sockport');
        $retval                    = $producer->write_config($config, "$system-install");
        return $retval if $retval;

        $self->install($system, $srv);
        $retval = $self->wait_for_systeminstaller($srv);
        
        my ($report_id, $error);
        if ($retval) {
                ($error, $report_id) = $net->tap_report_send($self->testrun, [{error => 1, msg => $retval}]);
                $net->upload_files($report_id, $self->testrun);
                return $retval;
        }
        
        $self->log->debug('waiting for test to finish');
        $retval              = $self->wait_for_testrun($srv, $mcp_info);
        ($error, $report_id) = $net->tap_report_send($self->testrun, $retval);
        return $report_id if $error;

        $retval = $net->upload_files($report_id, $self->testrun);
        return $retval if $retval;
        return 0;
        
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

