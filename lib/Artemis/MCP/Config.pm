package Artemis::MCP::Config;

use strict;
use warnings;

use File::Basename;
use Moose;
use Socket;
use Sys::Hostname;
use YAML;

use Artemis::Model 'model';
use Artemis::Config;
use Artemis::MCP::Info;
use Sys::Hostname;

extends 'Artemis::MCP::Control';

has mcp_info => (is  => 'rw',
                 default => sub {{}},
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
        $prc_config->{config}->{runtime}      = $self->cfg->{times}{test_runtime_default};
        $prc_config->{config}->{runtime}      = $guest->{testprogram}->{runtime} ||
          $self->cfg->{times}{test_runtime_default};

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
        my $main_prc_config;

        if ($config->{prcs}) {
                $main_prc_config = $config->{prcs}->[0];
        }

        # make sure host image is always first precondition
        unshift @{$config->{preconditions}}, $virt->{host}->{root};
        push @{$config->{preconditions}}, @{$virt->{host}->{preconditions}} if $virt->{host}->{preconditions};
        push @{$config->{preconditions}}, {precondition_type => 'package',
                                           filename => $self->cfg->{files}->{artemis_package}{$virt->{host}->{root}{arch}},
                                          } if  $self->cfg->{files}->{artemis_package}{$virt->{host}->{root}{arch}};
;

        # install host testprogram
        if ($virt->{host}->{testprogram}) {
                push @{$config->{preconditions}}, $virt->{host}->{testprogram};
                $main_prc_config->{test_program}        = $virt->{host}->{testprogram}->{execname};
                $main_prc_config->{parameters}          = $virt->{host}->{testprogram}->{parameters}          if $virt->{host}->{testprogram}->{parameters};
                $main_prc_config->{timeout_testprogram} = $virt->{host}->{testprogram}->{timeout_testprogram} if $virt->{host}->{testprogram}->{timeout_testprogram};
                $self->mcp_info->add_testprogram(0,{
                                                    timeout    => $self->{mcp_info}->{timeouts}->[0]->{end},
                                                    program    => $virt->{host}->{testprogram}->{execname},
                                                    parameters => $virt->{host}->{testprogram}->{parameters}
                                                   })    if $virt->{host}->{testprogram}->{timeout_testprogram};

        }
        push @{$main_prc_config->{timeouts}},$main_prc_config->{timeout_testprogram}; # always have a value for host, undef if no tests there



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
                        push @{$main_prc_config->{guests}}, {svm=>$guest->{config}->{svm}};
                } elsif ($guest->{config}->{kvm}) {
                        push @{$main_prc_config->{guests}}, {exec=>$guest->{config}->{kvm}};
                } elsif ($guest->{config}->{exec}) {
                        push @{$main_prc_config->{guests}}, {exec=>$guest->{config}->{exec}};
                }

                $retval = $self->add_guest_testprogram($config, $guest, $guest_number) if $guest->{testprogram};

                # put guest preconditions into precondition list
                foreach my $guest_precondition(@{$guest->{preconditions}}) {
                        $guest_precondition->{mountpartition} = $guest->{mountpartition};
                        $guest_precondition->{mountfile} = $guest->{mountfile} if $guest->{mountfile};
                        push @{$config->{preconditions}}, $guest_precondition;
                }

        }
        # put host PRC config in precondition list
        $main_prc_config->{guest_count} = $guest_number;  # main prc needs to know number of guests
        $config->{prcs}->[0] = {precondition_type => 'prc', config => $main_prc_config};
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
        push @{$config->{preconditions}}, $opt_pkg if $opt_pkg;
        return $config;
}

=head2 parse_testprogram

Handle precondition testprogram. Make sure testprogram is correctly to config
and internal information set.

@param hash ref - config to change
@param hash ref - precondition as hash

@return success - config hash
@return error   - error string

=cut

sub parse_testprogram
{
        my ($self, $config, $testprogram) = @_;
        my $prc_config;
        $prc_config = $config->{prcs}->[0] if $config->{prcs};
        no warnings 'uninitialized';
        push @{$config->{prcs}->[0]->{config}->{testprogram_list}}, $testprogram;
        $self->mcp_info->add_testprogram(0, $testprogram);
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
        my $file = $autoinstall->{filename} or die Artemis::Exception::Param->new(msg => qq(autoinstall does not have a value for filename));
        if (-e $file) {
                $config->{installer_grub} = $file;
        }elsif (-e $self->cfg->{paths}->{autoinstall}{grubfiles}.$file) {
                $config->{installer_grub} = $self->cfg->{paths}->{autoinstall}{grubfiles}.$file;
        } else {
                return "Can't find autoinstaller for $file";
        }

        $config->{autoinstall} = 1;
        my $timeout = $autoinstall->{timeout} || $self->cfg->{times}{installer_timeout};
        $self->mcp_info->set_installer_timeout($timeout);
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
        $config->{mcp_port}                  = $self->cfg->{mcp_port};
        $config->{report_server}             = $self->cfg->{report_server};
        $config->{report_port}               = $self->cfg->{report_port};
        $config->{report_api_port}           = $self->cfg->{report_api_port};
        $config->{prc_nfs_server}            = $self->cfg->{prc_nfs_server}
          if $self->cfg->{prc_nfs_server}; # prc_nfs_path is set by merging paths above
        $config->{test_run}                  = $testrun;
        return ($config)
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
                push @$retval, $self->mcp_info->get_testprograms($i);
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
        my ($self) = @_;
        my $config = $self->get_common_config();
        return $config if not ref $config eq 'HASH';

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
        open (FILE, ">", $cfg_file)
          or return "Can't open config file $cfg_file for writing: $!";
        print FILE $cfg;
        close FILE;
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
