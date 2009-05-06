package Artemis::MCP::Config;

use strict;
use warnings;

use File::Basename;
use Moose;
use Socket;
use YAML;

use Artemis::Model 'model';
use Artemis::Config;

extends 'Artemis::MCP::Control';

has mcp_info => (is  => 'rw',
                 isa => 'HashRef',
                 default => sub {{}},
                );

our $MODIFIER = 3; # timeout = $MODIFIER * runtime; XXX find better way 

=head1 NAME

Artemis::MCP::Config - Generate config for a certain test run

=head1 SYNOPSIS

 use Artemis::MCP::Config;

=head1 FUNCTIONS

=cut

=head2 parse_virt_preconditions

Unpack a precondition virt entry into images, packages and files to be
installed for this virt package to work.

@param hash ref - config has to which virt precondition should be added
@param hash ref - precondition as hash

@return success - hash reference containing the new config
@return error   - error string

=cut 

sub parse_virt_preconditions
{
        
        my ($self, $config, $virt) = @_;
        unshift @{$config->{preconditions}}, $virt->{host}->{root};
        push @{$config->{preconditions}}, @{$virt->{host}->{preconditions}} if $virt->{host}->{preconditions};
        return "can't detect architecture of one guest, so I can't install PRC" 
          if not $self->cfg->{files}->{artemis_package}{$virt->{host}->{root}{arch}};
        push @{$config->{preconditions}}, {precondition_type => 'package', 
                                           filename => $self->cfg->{files}->{artemis_package}{$virt->{host}->{root}{arch}},
                                          };
        
        my $main_prc_config;
        
        # install host testprogram
        if ($virt->{host}->{testprogram}) {
                push @{$config->{preconditions}}, $virt->{host}->{testprogram};
                $main_prc_config->{test_program}              = $virt->{host}->{testprogram}->{execname};
                $main_prc_config->{parameters}                = $virt->{host}->{testprogram}->{parameters}                if $virt->{host}->{testprogram}->{parameters};
                $main_prc_config->{timeout_testprogram} = $virt->{host}->{testprogram}->{timeout_testprogram} if $virt->{host}->{testprogram}->{timeout_testprogram};
                $self->{mcp_info}->{timeouts}->[0]->{end}     = $virt->{host}->{testprogram}->{timeout_testprogram} if $virt->{host}->{testprogram}->{timeout_testprogram};
                
        }
        push @{$main_prc_config->{timeouts}},$main_prc_config->{timeout_testprogram}; # always have a value for host, undef if no tests there
        

        
        # Not all guests need to have a test program and thus a PRC
        # running. Count those which do to allow proxy to report number of
        # missing guests. Note that guest 0 is actually HOST
        my $guest_number ;
        for (my $i=0; $i<=$#{$virt->{guests}}; $i++ ) {
                my $guest = $virt->{guests}->[$i];
                $guest_number = $i+1;
                my $mountfile      = $guest->{root}->{mountfile};
                my $mountpartition = $guest->{root}->{mountpartition};

                # if we have a qcow image, we need a raw image to copy PRC stuff to
                if ($guest->{root}{mounttype} eq 'raw') {
                        my $raw_image = {
                                         precondition_type => 'rawimage',
                                         name              => basename($mountfile),
                                         path              => dirname($mountfile)
                                        };
                        push @{$config->{preconditions}}, $raw_image;
                }

                delete $guest->{root}->{mountpartition};
                delete $guest->{root}->{mountfile} if $guest->{root}->{mountfile};
                
                push @{$config->{preconditions}}, $guest->{root} if $guest->{root}->{precondition_type};
                push @{$config->{preconditions}}, $guest->{config};
                if ($guest->{config}->{svm}) {
                        push @{$main_prc_config->{guests}}, {svm=>$guest->{config}->{svm}};
                } elsif ($guest->{config}->{kvm}) {
                        push @{$main_prc_config->{guests}}, {exec=>$guest->{config}->{kvm}};
                } elsif ($guest->{config}->{exec}) {
                        push @{$main_prc_config->{guests}}, {exec=>$guest->{config}->{exec}};
                }


            

                
                if ($guest->{testprogram}) {
                        my $prc_config->{precondition_type} = 'prc';

                        $prc_config->{artemis_package} = $self->cfg->{files}->{artemis_package}{$guest->{root}{arch}};
                        return "can't detect architecture of one guest, so I can't install PRC" if not $prc_config->{artemis_package};

                        # put guest test program in guest prc config
                        $prc_config->{mountpartition} = $mountpartition;
                        $prc_config->{mountfile} = $mountfile if $mountfile;
                        $prc_config->{config}->{test_program}= $guest->{testprogram}->{execname};
                        $prc_config->{config}->{parameters} = $guest->{testprogram}->{parameters} 
                          if $guest->{testprogram}->{parameters};
                        $prc_config->{config}->{guest_number} = $guest_number;
                        $prc_config->{config}->{runtime} = $self->cfg->{times}{test_runtime_default};
                        $prc_config->{config}->{runtime} = $guest->{testprogram}->{runtime} ||
                          $self->cfg->{times}{test_runtime_default};

                        if ($guest->{testprogram}->{timeout_testprogram}) {
                                $prc_config->{config}->{timeout_testprogram}=$guest->{testprogram}->{timeout_testprogram} ;
                                push @{$main_prc_config->{timeouts}}, $guest->{testprogram}->{timeout_testprogram};
                        } else {
                                push @{$main_prc_config->{timeouts}}, $self->cfg->{times}{test_runtime_default} * $MODIFIER;
                        }
                        # push onto mcp_info timeout list, whatever the above if-cascade descided to use as timeout for this PRC
                        push @{$self->{mcp_info}->{timeouts}},{start => $self->cfg->{times}{boot_timeout}, 
                                                               end   => $main_prc_config->{timeouts}->[$#{$main_prc_config->{timeouts}}]};


                        push @{$config->{preconditions}}, $prc_config;

                        # put guest test program in precondition list
                        $guest->{testprogram}->{mountpartition} = $mountpartition;
                        $guest->{testprogram}->{mountfile}      = $mountfile if $mountfile;
                        push @{$config->{preconditions}}, $guest->{testprogram};
                        
                }
                
                # put guest preconditions into precondition list
                foreach my $guest_precondition(@{$guest->{preconditions}}) {
                        $guest_precondition->{mountpartition} = $mountpartition;
                        $guest_precondition->{mountfile} = $mountfile if $mountfile;
                        push @{$config->{preconditions}}, $guest_precondition;
                }

        }
        # put host PRC config in precondition list
        $main_prc_config->{guest_count} = $guest_number;  # main prc needs to know number of guests
        push @{$config->{preconditions}}, {precondition_type => 'prc', config => $main_prc_config};
   
        
        return $config;
}


=head2 parse_grub

Handle precondition grub. Even though a preconfigured grub config is provided
as precondition, it needs to get a special place in the Yaml file. Otherwise
it would be hard to find for the installer process generating the grub config
file.

@param hash reference - config to change
@param hash ref       - precondition as hash

@return success - config hash
@return error   - error string

=cut

sub  parse_grub
{
        my ($self, $config, $grub) = @_;
        $config->{grub}=$grub->{config};
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

        my $search=model('TestrunDB')->resultset('Testrun')->search({id => $self->{testrun},})->first();
        $self->mcp_info->{timeouts}=[{start=> $self->cfg->{times}{boot_timeout}, end => 0}];

        foreach my $precondition ($search->ordered_preconditions) {
                # make sure installing the root partition is always the first precondition
                if ($precondition->precondition_as_hash->{precondition_type} eq 'image' and 
                    $precondition->precondition_as_hash->{mount} eq '/'
                   ) {
                        unshift @{$config->{preconditions}}, $precondition->precondition_as_hash;
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'virt' ) {
                        $config=$self->parse_virt_preconditions($config, $precondition->precondition_as_hash);
                        # was not able to parse virtualisation precondition and thus
                        # return received error string
                        if (not ref($config) eq 'HASH' ) {
                                return $config;
                        }
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'grub') {
                        $config = $self->parse_grub($config, $precondition->precondition_as_hash);
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'installer_stop') {
                        $config->{installer_stop} = 1;
                }
                elsif ($precondition->precondition_as_hash->{precondition_type} eq 'reboot') {
                        $config->{max_reboot} = $precondition->precondition_as_hash->{count} || 1; # reboot at least once
                        $self->mcp_info->{max_reboot} = $config->{max_reboot};
                }
                else {
                        push @{$config->{preconditions}}, $precondition->precondition_as_hash;
                }
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
        $config->{mcp_host}                  = $self->cfg->{mcp_host};
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
        return $self->{mcp_info};
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
