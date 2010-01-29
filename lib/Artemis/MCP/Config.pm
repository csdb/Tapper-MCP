package Artemis::MCP::Config;

use strict;
use warnings;

use 5.010;
use File::Basename;
use Fcntl;
use File::Path::Tiny;
use LockFile::Simple;
use Moose;
use Socket;
use Sys::Hostname;
use YAML;

use Artemis::Model 'model';
use Artemis::Config;
use Artemis::MCP::Info;

extends 'Artemis::MCP::Control';

has mcp_info => (is  => 'rw',
                );

sub BUILD
{
        my ($self) = @_;
        $self->{mcp_info} = Artemis::MCP::Info->new();
}


our $MODIFIER = 3; # timeout = $MODIFIER * runtime; XXX find better way

=head1 NAME

Artemis::MCP::Config - Generate config for a certain test run

=head1 SYNOPSIS

 use Artemis::MCP::Config;

=head1 FUNCTIONS

=cut

=head2 add_guest_testprogram

Add a testprogram for a given guest to the config.

@param hash ref - config
@param hash ref - guest

@return success - new config (hash ref)
@return error   - error string

=cut

sub add_guest_testprogram
{

        my ($self, $config, $guest, $guest_number) = @_;
        my $prc_config->{precondition_type} = 'prc';

        $prc_config->{artemis_package} = $self->cfg->{files}->{artemis_package}{$guest->{root}{arch}};
#        return "can't detect architecture of one guest number $guest->{guest_number} so I can't install PRC" if not $prc_config->{artemis_package};

        # put guest test program in guest prc config
        $prc_config->{mountpartition}         = $guest->{mountpartition};
        $prc_config->{mountfile}              = $guest->{mountfile} if $guest->{mountfile};
        $prc_config->{config}->{test_program} = $guest->{testprogram}->{execname};
        $prc_config->{config}->{parameters}   = $guest->{testprogram}->{parameters}
          if $guest->{testprogram}->{parameters};
        $prc_config->{config}->{guest_number} = $guest_number;
        $prc_config->{config}->{runtime}      = $guest->{testprogram}->{runtime} || $self->cfg->{times}{test_runtime_default};

        my $timeout;
        if ($guest->{testprogram}->{timeout_testprogram}) {
                $timeout = $guest->{testprogram}->{timeout_testprogram};
                $prc_config->{config}->{timeout_testprogram} = $guest->{testprogram}->{timeout_testprogram};
        } else {
                $timeout = $self->cfg->{times}{test_runtime_default} * $MODIFIER;
        }
        my $retval = $self->mcp_info->add_testprogram($guest_number, {timeout => $timeout, program => $guest->{testprogram}->{execname}, parameters => $guest->{testprogram}->{parameters}} );
        return $retval if $retval;


        push @{$config->{preconditions}}, $prc_config;

        # put guest test program in precondition list
        $guest->{testprogram}->{mountpartition} = $guest->{mountpartition};
        $guest->{testprogram}->{mountfile}      = $guest->{mountfile} if $guest->{mountfile};
        push @{$config->{preconditions}}, $guest->{testprogram};
        return $config;
}


=head2 parse_virt_host

Parse host definition of a virt precondition and change config accordingly

@param hash ref - old config
@param hash ref - virt precondition

@return hash ref - new config

=cut

sub parse_virt_host
{
        my ($self, $config, $virt) = @_;
        given ($virt->{host}->{root}->{precondition_type}) {
                when ('image') {
                        $config = $self->parse_image_precondition($config, $virt->{host}->{root});
                }
                when ('autoinstall') {
                        $config = $self->parse_autoinstall($config, $virt->{host}->{root});
                }
        }

        # additional preconditions for virt host
        if ($virt->{host}->{preconditions}) {
                push @{$config->{preconditions}}, @{$virt->{host}->{preconditions}};
        }
        return $config;
}



=head2 parse_virt_preconditions

Unpack a precondition virt entry into images, packages and files to be
installed for this virt package to work.

@param hash ref - config hash to which virt precondition should be added
@param hash ref - precondition as hash

@return success - hash reference containing the new config
@return error   - error string

=cut

sub parse_virt_preconditions
{

        my ($self, $config, $virt) = @_;
        my $retval;

        $config = $self->parse_virt_host($config, $virt);
        $self->parse_testprogram($config, $virt->{host}->{testprogram}, 0) if $virt->{host}->{testprogram};

        my $guest_number;
        for (my $i=0; $i<=$#{$virt->{guests}}; $i++ ) {
                my $guest = $virt->{guests}->[$i];
                $guest_number = $i+1;
                $guest->{mountfile} = $guest->{root}->{mountfile};
                $guest->{mountpartition} = $guest->{root}->{mountpartition};
                delete $guest->{root}->{mountpartition};
                delete $guest->{root}->{mountfile} if $guest->{root}->{mountfile};


                $retval = $self->mcp_info->add_prc($guest_number, $self->cfg->{times}{boot_timeout});
                return $retval if $retval;

                # if we have a qcow image, we need a raw image to copy PRC stuff to
                if ($guest->{root}{mounttype} eq 'raw') {
                        my $raw_image = {
                                         precondition_type => 'rawimage',
                                         name              => basename($guest->{mountfile}),
                                         path              => dirname($guest->{mountfile})
                                        };
                        push @{$config->{preconditions}}, $raw_image;
                }


                push @{$config->{preconditions}}, $guest->{root} if $guest->{root}->{precondition_type};
                push @{$config->{preconditions}}, $guest->{config};
                if ($guest->{config}->{svm}) {
                        push @{$config->{prcs}->[0]->{config}->{guests}}, {svm=>$guest->{config}->{svm}};
                } elsif ($guest->{config}->{kvm}) {
                        push @{$config->{prcs}->[0]->{config}->{guests}}, {exec=>$guest->{config}->{kvm}};
                } elsif ($guest->{config}->{exec}) {
                        push @{$config->{prcs}->[0]->{config}->{guests}}, {exec=>$guest->{config}->{exec}};
                }

                $retval = $self->add_guest_testprogram($config, $guest, $guest_number) if $guest->{testprogram};

                # put guest preconditions into precondition list
                foreach my $guest_precondition(@{$guest->{preconditions}}) {
                        $guest_precondition->{mountpartition} = $guest->{mountpartition};
                        $guest_precondition->{mountfile} = $guest->{mountfile} if $guest->{mountfile};
                        push @{$config->{preconditions}}, $guest_precondition;
                }

        }
        $config->{prcs}->[0]->{config}->{guest_count} = $guest_number;

        return $config;
}


=head2 parse_grub

Handle precondition grub. Even though a preconfigured grub config is provided
as precondition, it needs to get a special place in the Yaml file. Otherwise
it would be hard to find for the installer process generating the grub config
file.

@param hash ref - config to change
@param hash ref - precondition as hash

@return success - config hash
@return error   - error string

=cut

sub  parse_grub
{
        my ($self, $config, $grub) = @_;
        $config->{grub}=$grub->{config};
        return $config;
}



=head2 parse_reboot

Handle precondition grub. Even though a preconfigured grub config is provided
as precondition, it needs to get a special place in the Yaml file. Otherwise
it would be hard to find for the installer process generating the grub config
file.

@param hash ref - config to change
@param hash ref - precondition as hash

@return success - config hash
@return error   - error string

=cut

sub  parse_reboot
{
        my ($self, $config, $reboot) = @_;
        $self->mcp_info->set_max_reboot(0, $reboot->{count});
        $config->{prcs}->[0]->{config}->{max_reboot} = $reboot->{count};
        return $config;
}

=head2 parse_image_precondition

Handle precondition image. Make sure the appropriate opt-artemis package is
installed if needed. Care for the root image being installed first.

@param hash ref - config to change
@param hash ref - precondition as hash

@return success - config hash
@return error   - error string

=cut

sub parse_image_precondition
{
        my ($self, $config, $precondition) = @_;
        my $opt_pkg;

        if ($precondition->{arch}) {
                $opt_pkg = {precondition_type => 'package',
                            filename => $self->cfg->{files}->{artemis_package}{$precondition->{arch}},
                           };
                $opt_pkg->{mountfile} = $precondition->{mountfile} if $precondition->{mountfile};
                $opt_pkg->{mountpartition} = $precondition->{mountpartition} if $precondition->{mountpartition};
                delete $precondition->{arch};
        }

        if ($precondition->{mount} eq '/') {
                unshift @{$config->{preconditions}}, $precondition;
        } else {
                push @{$config->{preconditions}}, $precondition;
        }

        if ($opt_pkg) {
                push @{$config->{preconditions}}, $opt_pkg;
                push @{$config->{preconditions}}, {precondition_type => 'exec', filename => '/opt/artemis/bin/artemis-testsuite-hwtrack', continue_on_error => 1 };
        }
        return $config;
}

=head2 parse_testprogram

Handle precondition testprogram. Make sure testprogram is correctly to config
and internal information set.

@param hash ref - config to change
@param hash ref - precondition as hash
@param int - prc_number, optional


@return success - config hash
@return error   - error string

=cut

sub parse_testprogram
{
        my ($self, $config, $testprogram, $prc_number) = @_;
        $prc_number //= 0;
        return "No timeout for testprogram" if not $testprogram->{timeout};
        no warnings 'uninitialized';
        push @{$config->{prcs}->[$prc_number]->{config}->{testprogram_list}}, $testprogram;
        $self->mcp_info->add_testprogram($prc_number, $testprogram);
        use warnings;
        return $config;

}


=head2 parse_autoinstall

Parse precondition autoinstall and change config accordingly.

@param hash ref - config to change
@param hash ref - precondition as hash

@return success - config hash
@return error   - error string

=cut

sub parse_autoinstall
{
        my ($self, $config, $autoinstall) = @_;

        if ($autoinstall->{grub_text}) {
                $config->{installer_grub} = $autoinstall->{grub_text};
        } elsif ($autoinstall->{grub_file}) {
                open my $fh, "<", $autoinstall->{grub_file} or return "Can not open grub file ( ".$autoinstall->{grub_file}." ):$!";
                $config->{installer_grub} = do {local $\; <$fh>};
                close $fh;
        } else {
                return "Can not find autoinstaller grub config";
        }

        $config->{autoinstall} = 1;
        my $timeout = $autoinstall->{timeout} || $self->cfg->{times}{installer_timeout};
        $self->mcp_info->set_installer_timeout($timeout);
        
        my $artemis_host=$config->{mcp_host};
        my $artemis_port=$config->{mcp_port};
        my $packed_ip = gethostbyname($artemis_host);
        if (not defined $packed_ip) {
                return "Can not get an IP address for artemis_host ($artemis_host): $!";
        }
        my $artemis_ip=inet_ntoa($packed_ip);
        my $artemis_environment = Artemis::Config::_getenv();
        $config->{installer_grub} =~ 
          s|\$ARTEMIS_OPTIONS|artemis_ip=$artemis_ip artemis_host=$artemis_host artemis_port=$artemis_port artemis_environment=$artemis_environment|g;
        
        return $config;
}


=head2 get_install_config

Add installation configuration part to a given config hash.

@param hash reference - config to change

@return success - config hash
@return error   - error string

=cut

sub get_install_config
{
        my ($self, $config) = @_;

        my $search = model('TestrunDB')->resultset('Testrun')->search({id => $self->{testrun},})->first();
        my $retval = $self->mcp_info->add_prc(0, $self->cfg->{times}{boot_timeout});
        return $retval if $retval;

        foreach my $precondition ($search->ordered_preconditions) {
                # make sure installing the root partition is always the first precondition
                if ($precondition->precondition_as_hash->{precondition_type} eq 'image' ) {
                        $config = $self->parse_image_precondition($config, $precondition->precondition_as_hash);
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'virt' ) {
                        $config=$self->parse_virt_preconditions($config, $precondition->precondition_as_hash);
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'grub') {
                        $config = $self->parse_grub($config, $precondition->precondition_as_hash);
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'installer_stop') {
                        $config->{installer_stop} = 1;
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'reboot') {
                        $config = $self->parse_reboot($config, $precondition->precondition_as_hash);
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'autoinstall') {
                        $config = $self->parse_autoinstall($config, $precondition->precondition_as_hash);
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'testprogram') {
                        $config = $self->parse_testprogram($config, $precondition->precondition_as_hash);
                }
                else {
                        push @{$config->{preconditions}}, $precondition->precondition_as_hash;
                }

                # was not able to parse precondition and thus
                # return received error string
                if (not ref($config) eq 'HASH' ) {
                        return $config;
                }
        }
        while (my $prc_precondition = shift(@{$config->{prcs}})){
                $prc_precondition->{precondition_type} = "prc";
                push(@{$config->{preconditions}}, $prc_precondition);
        }
        return $config;
}


=head2 get_common_config

Create configuration to be used for installation on a given host.

@return success - config hash reference
@return error   - error string

=cut

sub get_common_config
{
        my ($self) = @_;
        my $config;
        my $testrun = $self->{testrun};
        my $search=model('TestrunDB')->resultset('Testrun')->search({id => $testrun})->first();
        return "Testrun $testrun not found in the database" if not $search;

        $config->{paths}                     = $self->cfg->{paths};
        $config->{times}                     = $self->cfg->{times};
        $config->{files}                     = $self->cfg->{files};
        $config->{mcp_host}                  = Sys::Hostname::hostname() || $self->cfg->{mcp_host};
        $config->{mcp_server}                = $config->{mcp_host};
        $config->{mcp_port}                  = $self->cfg->{mcp_port};
        $config->{sync_port}                 = $self->cfg->{sync_port};
        $config->{report_server}             = $self->cfg->{report_server};
        $config->{report_port}               = $self->cfg->{report_port};
        $config->{report_api_port}           = $self->cfg->{report_api_port};
        $config->{prc_nfs_server}            = $self->cfg->{prc_nfs_server}
          if $self->cfg->{prc_nfs_server}; # prc_nfs_path is set by merging paths above
        $config->{test_run}                  = $testrun;

        if ($search->scenario_element) {
                $config->{scenario_id} = $search->scenario_element->scenario_id;
                my $path = $config->{paths}{sync_path}."/".$config->{scenario_id}."/";
                $config->{files}{sync_file} = "$path/syncfile";

                if ($search->scenario_element->peer_elements->first->testrun->id == $testrun) {
                        if (not -d $path) {
                                if (not File::Path::Tiny::mk($path)) {
                                        # path could exists now due to race condition
                                        return "Could not make path '$path': $!" if not -d $path;
                                }
                        }
                        my @peers = map {$_->testrun->testrun_scheduling->host->name} $search->scenario_element->peer_elements->all;
                        if (sysopen(my $fh, $config->{files}{sync_file}, O_CREAT | O_EXCL |O_RDWR )) {
                                print $fh $search->scenario_element->peer_elements->count;
                                close $fh;
                        }       # else trust the creator
                        eval {
                                YAML::DumpFile($config->{files}{sync_file}, \@peers);
                        };
                        return $@ if $@;
                }
        }
        return ($config);
}


=head2 get_mcp_info

Returns mcp_info attribute, no matter if its already set.

@return hash reference

=cut

sub get_mcp_info
{
        my ($self) = @_;

        return $self->mcp_info;
}


=head2 get_test_config

Returns a an array of configs for all PRCs of a given test. All information
are taken from the MCP::Info attribute of the object so its only save to call
this function after create_config which configures this attribute.

@return success - config array (array ref)
@return error   - error string

=cut

sub get_test_config
{
        my ($self) = @_;
        my $retval;


        for (my $i=0; $i<=$self->mcp_info->get_prc_count(); $i++) {
                push @$retval, {testprogram_list => [ $self->mcp_info->get_testprograms($i) ]};
        }
        return $retval;
}


=head2 create_config

Create a configuration for the current status of the test machine. All config
information are taken from the database based upon the given testrun id.

@return success - config (hash reference)
@return error   - error string

=cut

sub create_config
{
        my ($self, $port) = @_;
        my $config = $self->get_common_config();
        return $config if not ref $config eq 'HASH';
        $config->{mcp_port}        = $port;

        $config    = $self->get_install_config($config);
        return $config;
}

=head2 write_config

Write the config created before into appropriate YAML file.

@param string - config (hash reference)
@param string - output file name, in absolut form or relative to configured localdata_path

@return success - 0
@return error   - error string

=cut

sub write_config
{
        my ($self, $config, $cfg_file) = @_;
        my $cfg = YAML::Dump($config);
        $cfg_file = $self->cfg->{paths}{localdata_path}.$cfg_file if not $cfg_file =~ m(/);
        open (my $file, ">", $cfg_file)
          or return "Can't open config file $cfg_file for writing: $!";
        print $file $cfg;
        close $file;
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
