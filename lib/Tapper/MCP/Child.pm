package Tapper::MCP::Child;

use 5.010;
use strict;
use warnings;

use Hash::Merge::Simple qw/merge/;
use List::Util qw(min max);
use Moose;
#use UNIVERSAL;
use YAML::Syck;

use Tapper::MCP::Net;
use Tapper::MCP::Config;
use Tapper::Model 'model';
use Tapper::MCP::State;

use constant BUFLEN     => 1024;
use constant ONE_MINUTE => 60;


extends 'Tapper::MCP::Control';
with 'Tapper::MCP::Net::TAP';

has state    => (is => 'rw');
has mcp_info => (is => 'rw');
has rerun    => (is => 'rw', default => 0);


=head1 NAME

Tapper::MCP::Child - Control one specific testrun on MCP side

=head1 SYNOPSIS

 use Tapper::MCP::Child;
 my $client = Tapper::MCP::Child->new($testrun_id);
 $child->runtest_handling($system);


=head1 FUNCTIONS




=head2 get_messages

Read all pending messages from database. Try no more than timeout seconds

@param file descriptor - read from this socket

@return success - Resultset class countaining all available messages
@return timeout - Resultset class countaining zero messages



=cut

sub get_messages
{
        my ($self, $timeout) = @_;
        my $end_time = time() + $timeout;

        my $messages;
        while () {
                $messages = $self->testrun->message;
                last if ($messages and $messages->count) or time() > $end_time;
                sleep 1;
        }
        return $messages;
}



=head2 wait_for_testrun

Wait for the current testrun and update state based on messages.

@return hash { report_array => reference to report array, prc_state => $prc_state }

=cut

sub wait_for_testrun
{
        my ($self) = @_;

        my $timeout_span = $self->state->get_current_timeout_span();
        my $error;

 MESSAGE:
        while (1) {
                my $msg = $self->get_messages($timeout_span);
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

        my ($self, $hostname ) = @_;
        my $retval;

        my $producer = Tapper::MCP::Config->new($self->testrun);

        $self->log->debug("Create install config for $hostname");
        my $config   = $producer->create_config();
        return $config if not ref($config) eq 'HASH';

        $retval = $producer->write_config($config, "$hostname-install");
        return $retval if $retval;

        if ($config->{autoinstall}) {
                my $common_config = $producer->get_common_config();
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

@param Tapper::MC::Net object

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

        my $net    = Tapper::MCP::Net->new();
        $net->cfg->{testrun_id} = $self->testrun->id;
        my $error;

        my $config = $self->generate_configs($hostname);
        return $config if ref $config ne 'HASH';
        $self->log->debug("Reviving testrun ",$self->testrun->id) if $revive;

        $self->state(Tapper::MCP::State->new(testrun_id => $self->testrun->id, cfg => $config));
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

                        my $report;
                        ($error, $report) = $net->hw_report_create($self->testrun->id);
                        if ($error) {
                                $self->log->error($report);
                        } else {
                                $self->tap_report_away($report);
                        }
                }
                my $message = model('TestrunDB')->resultset('Message')->new
                  ({
                   message => {state => 'takeoff'},
                   testrun_id => $self->testrun->id,
                   });
                $message->insert;
                $self->state->update_state($message);
        }

        $self->log->debug('waiting for test to finish');
        $self->wait_for_testrun();
        $self->report_mcp_results($net);
        return 0;

}

1;

=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 BUGS

None.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

 perldoc Tapper


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd

