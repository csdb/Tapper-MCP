package Artemis::MCP::Child;

use strict;
use warnings;

use IO::Select;
use IO::Socket::INET;
use List::Util qw(min max);
use Moose;
use UNIVERSAL qw (can);

use Artemis::MCP::Net;
use Artemis::MCP::Config;

use constant BUFLEN => 1024;


extends 'Artemis::MCP::Control';


has mcp_info => (is  => 'rw',
                 isa => 'HashRef',
                 default => sub {{}},
                );

=head1 NAME

Artemis::MCP::Child - Control one specific testrun on MCP side

=head1 SYNOPSIS

 use Artemis::MCP::Child;
 my $client = Artemis::MCP::Child->new($testrun_id);
 $child->runtest_handling($system);


=head1 FUNCTIONS



=head2 gettimeout

Determine timeout for tests in testrun with given id.

@param int - test run id

@return success - timeout
@return error   - undef

=cut

sub gettimeout
{
        my ($self) = @_;
        my $run = model->resultset('Testrun')->search({id=>$self->testrun})->first();
        return 0 if not $run;
        $self->log->debug(qq(Timeout is "$run->{wait_after_tests}"'));
        return $run->wait_after_tests || 0;
}

=head2 net_read

Reads new message from network socket. 

This function can be mocked when
testing allowing messages to come from a file during tests.

@param file handle - read from this socket
@param int         - timeout in seconds

@return success - message string read from remote)
@return error   - undef (check $!)
@return timeout - 0


=cut

sub net_read
{
        my ($self, $fh, $timeout) = @_;
        my $msg;
        if ($fh->can('accept')) {
                my $sock           = $fh->accept();
                $fh = $sock;
        }

        my $select = IO::Select->new() or return undef;
        $select->add($fh);
        
 NETREAD:
        while (1) {
                my $time   = time();
                my @ready  = $select->can_read($timeout);
                $timeout  -= time() - $time;
                return 0 if not @ready;
                my $tmp;
                my $readbytes = sysread($fh, $tmp, BUFLEN);
                last NETREAD if not $readbytes;
                $msg     .= $tmp;
        }
        chomp $msg;
        return $msg;
};


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
        if (not $msg) {
                return "$!" if not defined($msg);
                return {timeout => $timeout};
        }

        my ($number, $state, $error, $count);
        return {state => "$state-install", error => $error} 
          if ($state, undef, $error) = $msg =~ m/(start|end|error)-install(:(.+))?/;
        
        # prc_number:0,end-testprogram,prc_count:1
        return {state   => "$state-test",
                error   => $error,
                prc_number => $number,
                prc_count => $count} if 
                  ($number, $state, undef, $error, $count) = $msg =~ m/prc_number:(\d+),(start|end|error)-testprogram(:(.+))?,prc_count:(\d+)/ ;
        return qq(Can't parse message "$msg" received from system installer);
}

=head2 set_prc_status

Set timeouts in prc status array.

@return success - array ref to prc status array
@return error   - error string

=cut

sub set_prc_status
{
        my ($self, $mcp_info) = @_;
        return $mcp_info->{timeouts};
}

=head2 wait_for_systeminstaller

Wait for status messages of System Installer and apply timeout on
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
        
        if (not $msg->{status} eq "start-install") {
                return qq(MCP expected status start-install but remote system is in status $msg->{status});
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
                return  qq(MCP expected status end-install or error-install but remote system is in status "$msg->{status}");
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
        my ($self, $elapsed, $prc_status, $to_start, $to_stop) = @_;
        my $test_timeout;
        my $boot_timeout;

 PRC:
        for (my $i=0; $i<=$#{$prc_status}; $i++) {
                if ($prc_status->[$i]->{start} != 0) {
                        if (($prc_status->[$i]->{start} - $elapsed) <= 0) {
                                $prc_status->[$i]->{start} = 0;
                                $prc_status->[$i]->{end}  = 0;
                                $prc_status->[$i]->{error} = "Guest $i: booting not finished in time, timeout reached";
                                $to_start--;
                                $to_stop--;
                                next PRC;
                        } else {
                                $prc_status->[$i]->{start}= $prc_status->[$i]->{start} - $elapsed;
                        }
                        $boot_timeout = $prc_status->[$i]->{start} if not defined($boot_timeout);
                        $boot_timeout = min($boot_timeout, $prc_status->[$i]->{start});

                } elsif ($prc_status->[$i]->{end} != 0) {
                        if (($prc_status->[$i]->{end} - $elapsed) <= 0) {
                                $prc_status->[$i]->{end}  = 0;
                                $prc_status->[$i]->{error} = "Host: Testing not finished in time, timeout reached";
                                $prc_status->[$i]->{error} = "Guest $i: Testing not finished in time, timeout reached" if $i != 0;  # avoid another if/then/else, simply overwrite error for guests
                                $to_stop--;
                                next PRC;
                        } else {
                                $prc_status->[$i]->{end}= $prc_status->[$i]->{end} - $elapsed;
                        }
                        
                        $test_timeout = $prc_status->[$i]->{end} if not defined($test_timeout);
                        $test_timeout = min($test_timeout, $prc_status->[$i]->{end})
                }
        }
        return ($boot_timeout, $prc_status, $to_start, $to_stop) if $boot_timeout;
        return (max(1,$test_timeout), $prc_status, $to_start, $to_stop);

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
        my $error_occured=0;
      
        my $prc_status = $self->set_prc_status($mcp_info);
        my $to_start   = $#{$prc_status};  
        my $to_stop    = $to_start;
        $to_stop++ if $prc_status->[0]->{end};   # don't need to count starting of PRC0 but do need to count stopping

        # eval block used for timeout
        my $timeout = $self->cfg->{times}{boot_timeout};
        my $msg     = $self->get_message($fh, $timeout);
        return [{error=> 1, msg => $msg}] if not ref($msg) eq 'HASH';
        return [{error=> 1, msg => "Failed to boot test machine after timeout of $msg->{timeout} seconds"}] if $msg->{timeout};
        $prc_status->[0]->{start} = 0;


 MESSAGE:
        while (1) {
                my $lastrun = time();
                $msg=$self->get_message($fh, $timeout);
                return $msg if not ref($msg) eq 'HASH';

                $self->log->debug(qq(status $msg->{status} in PRC $msg->{prc_number}, last PRC is $msg->{prc_count}));
                        
                $self->log->error("Received PRC count of $msg->{prc_count} for testrun $self->{testrun} but we have ".($#{$prc_status} + 1)." PRCs in the config")
                  if ($#{$prc_status} + 1) != $msg->{prc_count};
                        
                my $number = $msg->{prc_number}; # just to make the code shorter

                if ($msg->{state} eq 'test-start') {
                        $prc_status->[$number]->{start} = 0;
                        $to_start--;
                } elsif ($msg->{state} eq 'test-end') {
                        $prc_status->[$number]->{end} = 0;
                        $to_stop--;
                } elsif ($msg->{state} eq 'test-error') {
                        $prc_status->[$number]->{end} = 0;
                        $error_occured=1;
                        $prc_status->[$number]->{error} = $msg->{error};
                        $to_stop--;
                } else {
                        $self->log->error("Unknown state $msg->{state} for PRC $msg->{prc_number}");
                }
                last MESSAGE if $to_stop <= 0;
                
                ($timeout, $prc_status, $to_start, $to_stop) = $self->time_reduce(time() - $lastrun, $prc_status, $to_start, $to_stop)

        }
        my @report;
        return \@report;
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
     
        my $remote                 = new Artemis::MCP::Net;
        $self->log->debug("Write grub file for $hostname");
        $retval                    = $remote->write_grub_file($hostname);
        return $retval if $retval;


        $self->log->debug("rebooting $hostname");
        $remote->reboot_system($hostname);
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

