package Artemis::MCP::Child;

use 5.010;
use strict;
use warnings;

use Hash::Merge::Simple qw/merge/;
use IO::Select;
use IO::Socket::INET;
use List::Util qw(min max);
use Moose;
#use UNIVERSAL;
use YAML::Syck;

use Artemis::MCP::Net;
use Artemis::MCP::Config;
use Artemis::Model 'model';
use Artemis::MCP::State;

use constant BUFLEN     => 1024;
use constant ONE_MINUTE => 60;


extends 'Artemis::MCP::Control';
with 'Artemis::MCP::Net::TAP';

has state    => (is => 'rw');
has mcp_info => (is => 'rw');
has rerun    => (is => 'rw', default => 0);


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

@return success - message string read from remote
@return timeout - undef

=cut

sub net_read_do
{
        my ($self, $fh, $timeout) = @_;
        my $msg;
        my $timeout_calc = $timeout;
        my $select = IO::Select->new() or return;
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
                return if not @ready;
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

@return success - hash reference containing message
@return timeout - undef

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
                return if $@=~m/Timeout/;
                $msg = $self->net_read_do($sock, $timeout);
        }
        else {
                $msg = $self->net_read_do($fh, $timeout);
        }
        alarm 0;
        return if not $msg;
        my $yaml = Load($msg);
        return $yaml;

}


=head2 get_message

Read a message from socket.

@param file descriptor - read from this socket

@return success - hash reference containing received information
@return timeout - undef



=cut

sub get_message
{
        my ($self, $fh, $timeout) = @_;
        return $self->net_read($fh, $timeout);
}



=head2 wait_for_testrun



@param int - testrun id
@param file handle - read from this handle

@return hash { report_array => reference to report array, prc_state => $prc_state }

=cut

sub wait_for_testrun
{
        my ($self, $fh) = @_;

        my $timeout_span = $self->state->get_current_timeout_span();
        my $error;

 MESSAGE:
        while (1) {
                my $msg = $self->get_message($fh, $timeout_span);
                ($error, $timeout_span) = $self->state->update_state($msg);
                if ($error) {
                        last MESSAGE if $self->state->testrun_finished;
                }
        }
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


=head2 report_mcp_results

Send TAP reports of MCP results in general and the results collected for each PRC.

@param Artemis::MC::Net object

=cut

sub report_mcp_results
{
        my ($self, $net) = @_;

        my $headerlines = $self->mcp_headerlines();
        my $mcp_results = $self->state->state_details->results();
        my ($error, $report_id) = $self->tap_report_send($mcp_results, $headerlines);
        if ($error) {
                $self->log->error('Can not send TAP report for testrun '.$self->testrun->id.
                                  " on ".$self->cfg->{hostname}.": $report_id");
                return;
        }

        my $prc_count = $self->state->state_details->prc_count;
 PRC_RESULT:
        for (my $prc_number = 0; $prc_number < $prc_count; $prc_number++)
        {
                my $prc_results = $self->state->state_details->prc_results($prc_number);
                next PRC_RESULT if not (ref($prc_results) eq 'ARRAY' and @$prc_results);
                $headerlines = $self->prc_headerlines($prc_number);
                $self->tap_report_send($prc_results, $headerlines);
        }
        $self->upload_files($report_id, $self->testrun->id );
}

=head2 runtest_handling

Start testrun and wait for completion.

@param string - system name
@param bool   - revive mode?


@return success - 0
@return error   - error string

=cut

sub runtest_handling
{

        my  ($self, $hostname, $revive) = @_;

        my $srv    = IO::Socket::INET->new(Listen=>5, Proto => 'tcp');
        return("Can't open socket for testrun ".$self->testrun->id.":$!") if not $srv;
        my $net    = Artemis::MCP::Net->new();
        my $error;

        # check if $srv really knows sockport(), because in case of a test
        # IO::Socket::INET is overwritten to read from a file
        my $port = 0;
        $port    = $srv->sockport if $srv->can('sockport');

        my $config = $self->generate_configs($hostname, $port);
        return $config if ref $config ne 'HASH';

        $self->state(Artemis::MCP::State->new(testrun_id => $self->testrun->id, cfg => $config));
        $self->state->state_init($self->mcp_info->get_state_config, $revive );

        if ($self->state->compare_given_state('reboot_install') == 1) {
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
                        $self->log->error($error) if $error;
                }
                $self->state->update_state({state => 'takeoff'});
        }

        $self->log->debug('waiting for test to finish');
        $self->wait_for_testrun($srv);
        $self->report_mcp_results($net);
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

