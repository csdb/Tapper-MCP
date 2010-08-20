package Artemis::MCP::Child;

use 5.010;
use strict;
use warnings;

use Hash::Merge::Simple 'merge';
use IO::Select;
use IO::Socket::INET;
use List::Util qw(min max);
use Moose;
use UNIVERSAL qw (can);
use YAML::Syck;

use Artemis::MCP::Net;
use Artemis::MCP::Config;
use Artemis::Model 'model';

use constant BUFLEN     => 1024;
use constant ONE_MINUTE => 60;


extends 'Artemis::MCP::Control';

has mcp_info => (is => 'rw');
has rerun    => (is => 'rw', default => 0);

=head1 NAME

Artemis::MCP::Child - Control one specific testrun on MCP side

=head1 SYNOPSIS

 use Artemis::MCP::Child;
 my $client = Artemis::MCP::Child->new($testrun_id);
 $child->runtest_handling($system);


=head1 FUNCTIONS


=head2 set_hardwaredb_systems_id

Set the actual hardwaredb_systems_id of the used test machine.

@param Testrun id object - found testrun result

@return success - 0
@return error   - error string

=cut

sub set_hardwaredb_systems_id
{
        my ($self, $hostname) = @_;

        my $testrun = model('TestrunDB')->resultset('Testrun')->find($self->testrun);
        return "Testrun with id ".$self->testrun." not found" if not $testrun;
        my $host = model('HardwareDB')->resultset('Systems')->search({systemname => $hostname, active => 1})->first;
        return "Can not find $hostname in hardware db, databases out of sync" if not $host;
        $testrun->hardwaredb_systems_id($host->lid);
        eval {
                $testrun->update();
        };
        return "Can not update host_id for testrun $testrun: $@" if $@;
        return 0;
}


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
        my ($self) = @_;
        my $prc_count = $self->mcp_info->get_prc_count();
        my $prc_state;
        for (my $i=0; $i<=$prc_count; $i++) {
                my $max_reboot = $self->mcp_info->get_max_reboot($i);
                if ($max_reboot) {
                        $prc_state->[$i]->{max_reboot} = $max_reboot;
                        $prc_state->[$i]->{reboot}     = $self->mcp_info->get_boot_timeout($i);
                        for (my $j = 0; $j <= $max_reboot; $j++) {
                                push @{$prc_state->[$i]->{timeouts}}, $self->mcp_info->get_testprogram_timeouts($i);
                        }
                }
                $prc_state->[$i]->{start} = $self->mcp_info->get_boot_timeout($i);
                push @{$prc_state->[$i]->{timeouts}}, $self->mcp_info->get_testprogram_timeouts($i);
                $prc_state->[$i]->{end} =  ONE_MINUTE;   # give one minute for PRC to settle (i.e. time between sending start and end without any test)
        }
        return $prc_state;
}

=head2 wait_for_systeminstaller

Wait for state messages of System Installer and apply timeout on
booting to make sure we react on a system that is stuck while booting
into system installer. The time needed to install a system can vary
widely thus no timeout for installation is applied.

@param file handle - read from this file handle
@param hash ref    - config for testrun
@param Artemis::MCP::Net object - offers grub file writing methods


@return success - 0
@return error   - error string

=cut

sub wait_for_systeminstaller
{
        my ($self, $fh, $config, $remote) = @_;

        my $timeout = $self->mcp_info->get_installer_timeout() || $self->cfg->{times}{boot_timeout};

        my $msg = $self->get_message($fh, $timeout);
        return $msg if not ref($msg) eq 'HASH';
        return "Failed to boot Installer after timeout of $msg->{timeout} seconds" if $msg->{timeout};

        if ($msg->{state} eq 'quit') {
                my $retval = "Testrun canceled while waiting for installation start";
                $retval   .= "\n# ".$msg->{error} if $msg->{error};
                return $retval;
        }

        if (not $msg->{state} eq "start-install") {
                return qq(MCP expected state start-install but remote system is in state $msg->{state});
        }
        if ($config->{autoinstall}) {
                $remote->write_grub_file($config->{hostname},
                                         "timeout 2\n\ntitle Boot from first hard disc\n\tchainloader (hd0,1)+1");

        }

        $self->log->debug("Installation started for testrun ".$self->testrun);

        $timeout = $self->mcp_info->get_installer_timeout() || $self->cfg->{times}{installer_timeout};

        while ($msg=$self->get_message($fh, $timeout)) {
                return $msg if not ref($msg) eq 'HASH';
                return "Failed to finish installation after timeout of $msg->{timeout} seconds" if $msg->{timeout};

                given ($msg->{state})
                {
                        when('quit') {
                                my $retval = "Testrun canceled while waiting for installation start";
                                $retval   .= "\n# ".$msg->{error} if $msg->{error};
                                return $retval;
                        }
                        when ('end-install') {
                                $self->log->debug("Installation finished for testrun ".$self->testrun);
                                return 0;
                        }
                        when ('error-install') {
                                $self->rerun(1);
                                return $msg->{error};
                        }
                        when ('warn-install') {
                                $self->mcp_info->push_report_msg({error => 1, msg => $msg->{error}});
                        }
                        default {
                                return  qq(MCP expected state end-install or error-install but remote system is in state "$msg->{state}");
                        }
                }
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
                if ($prc_state->[$i]->{start} and $prc_state->[$i]->{start} != 0) {
                        if (($prc_state->[$i]->{start} - $elapsed) <= 0) {
                                $prc_state->[$i]->{start} = 0;
                                delete $prc_state->[$i]->{timeouts};
                                $prc_state->[$i]->{end}   = 0;
                                $result->{error} = 1;
                                $self->rerun(1);
                                if ($prc_state->[$i]->{max_reboot}) {
                                        $result->{msg} = "reboot-test-summary\n";
                                        $result->{msg}.= "   ---\n";
                                        $result->{msg}.= "   got:".($prc_state->[$i]->{count} || "0")."\n";
                                        $result->{msg}.= "   expected:$prc_state->[$i]->{max_reboot}\n";
                                        $result->{msg}.= "   ...\n";
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
                        # testprogram is finished, take it off timeout array
                        if ($prc_state->[$i]->{timeouts}->[0] eq 'flag') {
                                shift @{$prc_state->[$i]->{timeouts}};
                                next;
                        }
                        if (($prc_state->[$i]->{timeouts}->[0] - $elapsed) <= 0) {
                                shift @{$prc_state->[$i]->{timeouts}};
                                $result->{error} = 1;
                                $self->rerun(1);
                                $result->{msg}   = "Host: Testing not finished in time, timeout reached";
                                # avoid another if/then/else, simply overwrite error for guests
                                $result->{msg}   = "Guest $i: Testing not finished in time, timeout reached" if $i != 0;
                                push @{$prc_state->[$i]->{results}}, $result;
                                next PRC;
                        } else {
                                $prc_state->[$i]->{timeouts}->[0] -= $elapsed;
                        }
                } elsif ($prc_state->[$i]->{reboot}){
                        if (($prc_state->[$i]->{reboot} - $elapsed) <= 0) {
                                delete $prc_state->[$i]->{timeouts};
                                $prc_state->[$i]->{end}   = 0;
                                $result->{error} = 1;
                                $self->rerun(1);
                                $result->{msg} = "reboot-test-summary\n";
                                $result->{msg}.= "   ---\n";
                                $result->{msg}.= "   got:".($prc_state->[$i]->{count} || "0")."\n";
                                $result->{msg}.= "   expected:$prc_state->[$i]->{max_reboot}\n";
                                $result->{msg}.= "   catched_timeout: 1\n";
                                $result->{msg}.= "   ...\n";
                                $to_stop--;
                                push @{$prc_state->[$i]->{results}}, $result;
                                next PRC;
                        } else {
                                $prc_state->[$i]->{reboot}= $prc_state->[$i]->{reboot} - $elapsed;
                        }
                } elsif ($prc_state->[$i]->{end} != 0) {
                        if (($prc_state->[$i]->{end} - $elapsed) <= 0) {
                                $prc_state->[$i]->{end} = 0;
                                delete $prc_state->[$i]->{timeouts};
                                $result->{error} = 1;
                                $self->rerun(1);
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
                $newtimeout    = $prc_state->[$i]->{timeouts}->[0] if $prc_state->[$i]->{timeouts}->[0] and not $prc_state->[$i]->{timeouts}->[0] ~~ 'flag';
                $newtimeout    = $prc_state->[$i]->{reboot} if ($prc_state->[$i]->{reboot} and not $newtimeout);
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
                when ('sync')
                {
                        $prc_state->[$number]->{start} = $self->mcp_info->get_boot_timeout($number);
                        $result->{msg} = "Started syncing with peers";
                        push (@{$prc_state->[$number]->{results}}, $result);

                }
		when ('error-guest') {
                        $self->rerun(1);
                        $prc_state->[$number]->{start} = 0;
                        $prc_state->[$number]->{stop} = 0;
                        $prc_state->[$number]->{results} = {msg => "Error in guest $number: ".$msg->{error}, error => 1};
                        $to_start--; $to_stop--;
                }
                when ('error-testprogram') {
                        $self->rerun(1);
                        pop @{$prc_state->[$number]->{timeouts}};
                        $result->{error}             = $msg->{error};
                        $result->{msg}               = "Error in guest $number: $msg->{error}" if $number != 0;;
                        $result->{msg}               = "Error in PRC 0: $msg->{error}" if $number == 0;
                        $to_stop--;
                        push (@{$prc_state->[$number]->{results}}, $result);

                }
                when ('end-testprogram') {
                        shift @{$prc_state->[$number]->{testprograms}};
                        $prc_state->[$number]->{timeouts}->[0] = 'flag';   # signal time_reduce that this testprogram is finished
                        $result->{msg} = "Testprogram $msg->{testprogram} in guest $number" if $number != 0;
                        $result->{msg} = "Testprogram $msg->{testprogram} in PRC 0" if $number == 0;
                        push (@{$prc_state->[$number]->{results}}, $result);
                }
                when ('reboot') {
                        $prc_state->[$number]->{count} = $msg->{count};
                        if (not $msg->{max_reboot} eq $prc_state->[$number]->{max_reboot}) {
                                $self->log->warning("Got a new max_reboot count for PRC $number. Old value was $prc_state->[$number]->{max_reboot} ",
                                                    "new value is $msg->{max_reboot}. I continue with new value");
                                $prc_state->[$number]->{max_reboot} = $msg->{max_reboot};
                        }
                        if ($msg->{count} == $prc_state->[$number]->{max_reboot}) {
                                delete($prc_state->[$number]->{reboot});
                        }
                        $result->{msg} = "Reboot $msg->{count}";
                        $prc_state->[$number]->{start} = $prc_state->[$number]->{reboot};
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

@return hash { report_array => reference to report array, prc_state => $prc_state }

=cut

sub wait_for_testrun
{
        my ($self, $fh) = @_;

        my $prc_state = $self->set_prc_state($self->mcp_info);
        my $to_start   = scalar @$prc_state;
        my $to_stop    = $to_start;

        my $timeout = $self->mcp_info->get_boot_timeout(0) || $self->cfg->{times}{boot_timeout};

        my $msg     = $self->get_message($fh, $timeout);
        return { report_array => [{error=> 1, msg => $msg}]} if not ref($msg) eq 'HASH';
        return { report_array => [{error=> 1, msg => "Failed to boot test machine after timeout of $msg->{timeout} seconds"}]} if $msg->{timeout};
        if (($msg->{state} eq 'quit')) {
                my $retval = {error=> 1, msg => "Testrun canceled while running tests"};
                $retval->{comment} = $msg->{error} if $msg->{error};
                return {report_array => [ $retval ], prc_state => $prc_state};
        }

        ($prc_state, $to_start, $to_stop) = $self->update_prc_state($msg, $prc_state, $to_start, $to_stop);

 MESSAGE:
        while ($to_stop) {
                my $lastrun = time();
                $msg=$self->get_message($fh, $timeout);
                return $msg if not ref($msg) eq 'HASH';
                if (($msg->{state} and $msg->{state} eq 'quit')) {
                        my $retval = {error=> 1, msg => "Testrun canceled while running tests"};
                        $retval->{comment} = $msg->{error} if $msg->{error};
                        return {report_array => [ $retval ], prc_state => $prc_state};
                }

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
        return { report_array => \@report_array,
                 prc_state    => $prc_state,
               };
}


=head2 generate_configs

@param string   - hostname
@param int      - port number of server

@return success - config hash
@return error   - string

=cut

sub generate_configs
{

        my ($self, $hostname, $port ) = @_;
        my $retval;

        my $producer = Artemis::MCP::Config->new($self->testrun);

        $self->log->debug("Create install config for $hostname");
        my $config   = $producer->create_config($port);
        return $config if not ref($config) eq 'HASH';

        $retval = $producer->write_config($config, "$hostname-install");
        return $retval if $retval;

        if ($config->{autoinstall}) {
                my $common_config = $producer->get_common_config();
                $common_config->{mcp_port} = $port;
                $common_config->{hostname} = $hostname;  # allows guest systems to know their host system name

                my $testconfigs = $producer->get_test_config();
                return $testconfigs if not ref $testconfigs eq 'ARRAY';

                for (my $i=0; $i<= $#{$testconfigs}; $i++ ){
                        my $prc_config = merge($common_config, $testconfigs->[$i]);
                        $prc_config->{guest_number} = $i;
                        my $suffix = "test-prc$i";

                        $retval = $producer->write_config($prc_config, "$hostname-$suffix");
                        return $retval if $retval;
                }
        }
        $self->mcp_info($producer->get_mcp_info());
        $config->{hostname} = $hostname;
        return $config;
}

=head2 tap_report_send

Wrapper around tap_report_send.

@param Artemis::MC::Net object
@param

@return success - (0, report id)
@return error -   (1, error message)

=cut

sub tap_report_send
{
        my ($self, $net, $reportlines, $headerlines) = @_;
        return (1, "No valid report to send as tap") if not ref $reportlines eq "ARRAY";
        my $collected_report = $self->mcp_info->get_report_array();
        if (ref($collected_report) eq "ARRAY" and  @$collected_report) {
                unshift @$reportlines, @$collected_report;
        }

        return $net->tap_report_send($self->testrun, $reportlines, $headerlines);
}

sub tap_reports_prc_state {
        my ($self, $net, $prc_state) = @_;

        my $testrun_id = $self->testrun;
        my $run      = model->resultset('Testrun')->search({id=>$testrun_id})->first();
        my $host     = model('HardwareDB')->resultset('Systems')->find($run->hardwaredb_systems_id);
        my $hostname = $host->systemname if $host;
        $hostname = $hostname // 'No hostname set';
        $prc_state ||= [];

        foreach (my $i=0; $i < @$prc_state; $i++) {
                my $results = $prc_state->[$i]->{results};
                my $suitename =  ($i > 0) ? "Guest-Overview-$i" : "PRC0-Overview";

                my $headerlines = [
                                   "# Artemis-reportgroup-testrun: $testrun_id",
                                   "# Artemis-suite-name: $suitename",
                                   "# Artemis-suite-version: 1.0",
                                   "# Artemis-machine-name: $hostname",
                                   "# Artemis-section: prc-state-details",
                                   "# Artemis-reportgroup-primary: 0",
                                  ];
                my $reportlines = $results;
                my ($error, $report_id) = $self->tap_report_send($net, $reportlines, $headerlines);
        }
}

=head2 runtest_handling

Start testrun and wait for completion.

@param string - system name

@return success - 0
@return error   - error string

=cut

sub runtest_handling
{

        my  ($self, $hostname) = @_;
        #my $retval;

        my $hwdb_retval = $self->set_hardwaredb_systems_id($hostname);
        return $hwdb_retval if $hwdb_retval;

        my $srv    = IO::Socket::INET->new(Listen=>5, Proto => 'tcp');
        return("Can't open socket for testrun $self->{testrun}:$!") if not $srv;
        my $net    = Artemis::MCP::Net->new();

        # check if $srv really knows sockport(), because in case of a test
        # IO::Socket::INET is overwritten to read from a file
        my $port = 0;
        $port    = $srv->sockport if $srv->can('sockport');

        my $config = $self->generate_configs($hostname, $port);
        return $config if ref $config ne 'HASH';

        my ($report_id, $error);

        if ($self->mcp_info->is_simnow) {
                $self->log->debug("Starting Simnow on $hostname");
                my $simnow_retval = $net->start_simnow($hostname);
                return $simnow_retval if $simnow_retval;
        } else {
                $self->log->debug("Write grub file for $hostname");
                my $grub_retval = $net->write_grub_file($hostname, $config->{installer_grub});
                return $grub_retval if $grub_retval;

                $self->log->debug("rebooting $hostname");
                my $reboot_retval = $net->reboot_system($hostname);
                return $reboot_retval if $reboot_retval;

                $error = $net->hw_report_send($self->testrun);
                return $error if $error;
        }

        my $sysinstall_retval = $self->wait_for_systeminstaller($srv, $config, $net);

        my $suite_headerlines = $net->suite_headerlines($self->testrun);
        if ($sysinstall_retval) {
                ($error, $report_id) = $self->tap_report_send($net, [{error => 1, msg => $sysinstall_retval}], $suite_headerlines);
                if ($error) {
                        $self->log->error($report_id);
                } else {
                        $net->upload_files($report_id, $self->testrun);
                }
                return $sysinstall_retval;
        }

        $self->log->debug('waiting for test to finish');
        my $waittestrun_retval              = $self->wait_for_testrun($srv);

        my $reportlines = $waittestrun_retval->{report_array};
        unshift @$reportlines, {msg => "Installation finished"};

        $self->tap_reports_prc_state($net, $waittestrun_retval->{prc_state});

        ($error, $report_id) = $self->tap_report_send($net, $reportlines, $suite_headerlines);

        if ($error) {
                $self->log->error($report_id);
                return $waittestrun_retval;
        }

        my $upload_retval = $net->upload_files($report_id, $self->testrun);
        return $upload_retval if $upload_retval;
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

