package Artemis::MCP::Installer;

use strict;
use warnings;

use Log::Log4perl;
use Method::Signatures;
use Moose;
use Socket;
use YAML;
use Artemis::MCP::Config;
use Artemis::Model 'model';
use Artemis::Net::Server;

extends 'Artemis';


=head1 NAME

Artemis::Installer::Server - Control image installer from Artemis
host.

=head1 SYNOPSIS

 use Artemis::Installer::Server;


=cut 


=head1 FUNCTIONS

=head2 wait_for_systeminstaller

Wait for status messages of System Installer and apply timeout on
booting to make sure we react on a system that is stuck while booting
into system installer. The time needed to install a system can vary
widely thus no timeout for installation is applied.

@param int - testrun id
@param file handle - read from this file handle


@return success - 0
@return error   - error string

=cut 

method wait_for_systeminstaller($testrun_id, $fh)
{
        my $timeout = $self->cfg->{times}{boot_timeout};
        eval {
                $SIG{ALRM}=sub{die("timeout of $timeout seconds reached while booting system installer");};
                $timeout=0 if not $timeout; # to get rid of warnings in case get_timeout failed above
                alarm($timeout);

                        my $msg = <$fh>;
        
                if ($msg!~/start-install/) {
                        $self->log->error( qq(Expected start-install signal from System Installer but received "$msg"));
                        die qq(Expected start-install signal from System Installer but received "$msg");
                }
                $self->log->debug("Installation started for testrun $testrun_id");
        };
        alarm(0);
        return $@ if $@;

        my $msg=<$fh>;
        while (1) {
                my ($state, undef, $error) = $msg =~/(end|error)-install(:(.+))?/ or 
                  do {
                          $self->log->error(qq(Can't parse message "$msg" received from system installer, expected ),
                                            qq("end-install" or "error-install"));
                          return( qq(Can't parse message "$msg" received from system installer, expected ),
                                  qq("end-install" or "error-install"));
                  };

                if ($state eq 'end') {
                        $self->log->debug("Installation finished for testrun $testrun_id");
                        return 0;
                } elsif ($state eq 'error') {
                        return $error;
                }
        }
}
;


=head2 hostname

Return the name of a host instead of its id.

@return success - hostname

=cut

method get_hostname_for_hardware_id($hardwaredb_systems_id)
{
        model('HardwareDB')->resultset('Systems')->search({lid => $hardwaredb_systems_id,})->first->systemname;
};

=head2 install

Install all packages and images for a given testrun. 

@param int - database id of the testrun
@param file handle - read from this file handle

@return success - 0
@return error   - error string

=cut

method install($testrun_id, $fh)
{
        my $hardwaredb_systems_id = model('TestrunDB')->resultset('Testrun')->search({id => $testrun_id,})->first()->hardwaredb_systems_id;
        my $hostname = $self->get_hostname_for_hardware_id($hardwaredb_systems_id);
        my $retval;

        my $producer = new Artemis::Config::Producer;
        $self->log->debug("Create install config for $hostname");

        my $yaml;
        ($retval, $yaml) = $producer->create_config($testrun_id, 'install');
        return $yaml if $retval;
        $retval          = $producer->write_config($yaml, "$hostname-install");
        return $retval if $retval;

        my $remote   = new Artemis::Net::Server;
        $self->log->debug("Write grub file for $hostname");
        $retval      =  $remote->write_grub_file($hostname);
        return $retval if $retval;
        $self->log->debug("rebooting $hostname");
        $remote->reboot_system($hostname);
        $self->log->debug("waiting for system installer on  $hostname");
        $retval = $self->wait_for_systeminstaller($testrun_id, $fh);

        # having a $retval instead of return function() makes debugging easier
        # (additional step in which the value of $retval can be checked)
        return $retval;
};

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

