package Tapper::MCP::Config;

use strict;
use warnings;

use 5.010;
use File::Basename;
use Fcntl;
use File::Path;
use LockFile::Simple;
use Moose;
use Socket 'inet_ntoa';
use Sys::Hostname;
use YAML;

use Tapper::Model 'model';
use Tapper::Config;
use Tapper::MCP::Info;
use Tapper::Producer;

extends 'Tapper::MCP::Control';

has mcp_info => (is  => 'rw',
                );

sub BUILD
{
        my ($self) = @_;
        $self->{mcp_info} = Tapper::MCP::Info->new();
}


=head1 NAME

Tapper::MCP::Config - Generate config for a certain test run

=head1 SYNOPSIS

 use Tapper::MCP::Config;

=head1 FUNCTIONS

=cut

=head2 parse_simnow_preconditions

Parse a simnow precondition.

@param hash ref - config
@param hash ref - simnow precondition

@return success - 0

=cut

sub parse_simnow_preconditions
{
        my ($self, $config, $precondition) = @_;
        $self->mcp_info->is_simnow(1);
        return $config;
}

=head2 parse_simnow_preconditions

Parse a simnow precondition.

@param hash ref - config
@param hash ref - hint precondition

@return success - 0

=cut

sub parse_hint_preconditions
{
        my ($self, $config, $precondition) = @_;
        if ($precondition->{simnow}) {
                $self->mcp_info->is_simnow(1);
                $config->{paths}{base_dir}='/';
                $config->{files}{simnow_script} = $precondition->{script} if $precondition->{script};
        }
        push @{$config->{preconditions}}, {precondition_type => 'simnow_backend'};
        return $config;
}


=head2 add_tapper_package_for_guest

Add opt tapper package to guest

@param hash ref - config
@param hash ref - guest
@param int - guest number


@return success - new config (hash ref)
@return error   - error string

=cut

sub add_tapper_package_for_guest
{

        my ($self, $config, $guest, $guest_number) = @_;
        my $tapper_package->{precondition_type} = '';

        my $guest_arch                        = $guest->{root}{arch};
        $tapper_package->{filename}          = $self->cfg->{files}->{tapper_package}{$guest_arch};

        $tapper_package->{precondition_type} = 'package';
        $tapper_package->{mountpartition}    = $guest->{mountpartition};
        $tapper_package->{mountfile}         = $guest->{mountfile} if $guest->{mountfile};

        push @{$config->{preconditions}}, $tapper_package;
        return $config;
}


=head2 handle_guest_tests

Create guest PRC config based on guest tests.

@param hash ref - old config
@param hash ref - guest description
@param int      - guest number

@return success - new config hash ref
@return error   - error string

=cut

sub handle_guest_tests
{
        my ($self, $config, $guest, $guest_number) = @_;
        $config = $self->add_tapper_package_for_guest($config, $guest);
        return $config unless ref $config eq 'HASH';

        $config->{prcs}->[$guest_number]->{mountfile} = $guest->{mountfile};
        $config->{prcs}->[$guest_number]->{mountpartition} = $guest->{mountpartition};
        $config->{prcs}->[$guest_number]->{config}->{guest_number} = $guest_number;


        $config = $self->parse_testprogram($config, $guest->{testprogram}, $guest_number)
          if $guest->{testprogram};
        return $config unless ref $config eq 'HASH';

        $config = $self->parse_testprogram_list($config, $guest->{testprogram_list}, $guest_number)
          if $guest->{testprogram_list};
        return $config unless ref $config eq 'HASH';

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
        $config = $self->parse_testprogram($config, $virt->{host}->{testprogram}, 0) if $virt->{host}->{testprogram};
        $config = $self->parse_testprogram_list($config, $virt->{host}->{testprogram_list}, 0) if $virt->{host}->{testprogram_list};
        return $config unless ref($config) eq 'HASH';

        for (my $guest_number = 1; $guest_number <= int @{$virt->{guests} || []}; $guest_number++ ) {
                my $guest = $virt->{guests}->[$guest_number-1];

                $guest->{mountfile} = $guest->{root}->{mountfile};
                $guest->{mountpartition} = $guest->{root}->{mountpartition};
                delete $guest->{root}->{mountpartition};
                delete $guest->{root}->{mountfile} if $guest->{root}->{mountfile};


                $retval = $self->mcp_info->add_prc($guest_number, $self->cfg->{times}{boot_timeout});
                return $retval if $retval;

                # if we have a qcow image, we need a raw image to copy PRC stuff to
                no warnings 'uninitialized';
                given($guest->{root}{mounttype})
                {
                        when ('raw') {
                                my $raw_image = {
                                                 precondition_type => 'rawimage',
                                                 name              => basename($guest->{mountfile}),
                                                 path              => dirname($guest->{mountfile})
                                                };
                                push @{$config->{preconditions}}, $raw_image;
                        }
                        when ('windows') {
                                my $raw_image = {
                                                 precondition_type => 'copyfile',
                                                 name              => $self->cfg->{files}{windows_test_image},
                                                 dest              => $guest->{mountfile},
                                                 protocol          => 'nfs',
                                                };
                                push @{$config->{preconditions}}, $raw_image;
                        }
                }
                use warnings;

                push @{$config->{preconditions}}, $guest->{root} if $guest->{root}->{precondition_type};
                push @{$config->{preconditions}}, $guest->{config};
                if ($guest->{config}->{svm}) {
                        push @{$config->{prcs}->[0]->{config}->{guests}}, {svm=>$guest->{config}->{svm}};
                } elsif ($guest->{config}->{kvm}) {
                        push @{$config->{prcs}->[0]->{config}->{guests}}, {exec=>$guest->{config}->{kvm}};
                } elsif ($guest->{config}->{exec}) {
                        push @{$config->{prcs}->[0]->{config}->{guests}}, {exec=>$guest->{config}->{exec}};
                }

                if ($guest->{testprogram} or $guest->{testprogram_list}) {
                        $config = $self->handle_guest_tests($config, $guest, $guest_number);
                        return $config unless ref $config eq 'HASH';
                }

                # put guest preconditions into precondition list
                foreach my $guest_precondition(@{$guest->{preconditions}}) {
                        $guest_precondition->{mountpartition} = $guest->{mountpartition};
                        $guest_precondition->{mountfile} = $guest->{mountfile} if $guest->{mountfile};
                        push @{$config->{preconditions}}, $guest_precondition;
                }

        }
        $config->{prcs}->[0]->{config}->{guest_count} = int @{$virt->{guests} || []};

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

Handle precondition image. Make sure the appropriate opt-tapper package is
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
                            filename => $self->cfg->{files}->{tapper_package}{$precondition->{arch}},
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
                push @{$config->{preconditions}}, {precondition_type => 'exec',
                                                   filename => '/opt/tapper/perl/perls/current/bin/tapper-testsuite-hwtrack',
                                                   continue_on_error => 1 };
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

        if (not $testprogram->{timeout}) {
                $testprogram->{timeout} = $testprogram->{timeout_testprogram};
                delete $testprogram->{timeout_testprogram};
        }
        if ($testprogram->{execname}) {
                $testprogram->{program} = $testprogram->{execname};
                delete $testprogram->{execname};
        }
        $testprogram->{runtime} = $testprogram->{runtime} || $self->cfg->{times}{test_runtime_default};

        return "No timeout for testprogram" if not $testprogram->{timeout};
        no warnings 'uninitialized';
        push @{$config->{prcs}->[$prc_number]->{config}->{testprogram_list}}, $testprogram;
        $self->mcp_info->add_testprogram($prc_number, $testprogram);
        use warnings;
        return $config;

}

=head2 parse_testprogram_list

Handle testprogram list precondition. Puts testprograms to config and
internal information set.

@param hash ref - config to change
@param hash ref - precondition as hash
@param int - prc_number, optional


@return success - config hash
@return error   - error string

=cut

sub parse_testprogram_list
{
        my ($self, $config, $testprogram_list, $prc_number) = @_;

        return $config unless ref $testprogram_list eq 'ARRAY';
        foreach my $testprogram (@$testprogram_list) {
                $config = $self->parse_testprogram($config, $testprogram, $prc_number);
        }
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
        $config->{paths}{base_dir} = '/';
        my $timeout = $autoinstall->{timeout} || $self->cfg->{times}{installer_timeout};
        $self->mcp_info->set_installer_timeout($timeout);
        return $config;
}

=head2 update_installer_grub

Get the text for grub config file at booting into installation.

@param hash ref - config to change

@return success - config hash
@return error   - error string

=cut

sub update_installer_grub
{
        my ($self, $config)    = @_;
        my $tapper_host        = $config->{mcp_host};
        my $tapper_port        = $config->{mcp_port};

        my $packed_ip          = gethostbyname($tapper_host);
        if (not defined $packed_ip) {
                return "Can not get an IP address for tapper_host ($tapper_host): $!";
        }
        my $tapper_ip          = inet_ntoa($packed_ip);

        my $tapper_environment = Tapper::Config::_getenv();
        my $testrun            = $config->{test_run};

        if (not $config->{installer_grub} ) {

                my $nfsroot     = $config->{paths}{nfsroot};
                my $kernel      = $config->{files}{installer_kernel};
                my $tftp_server = $self->cfg->{tftp_server_address};

                $config->{installer_grub} = <<END;
serial --unit=0 --speed=115200
terminal serial

default 0
timeout 2

title Test
     tftpserver $tftp_server
     kernel $kernel earlyprintk=serial,ttyS0,115200 console=ttyS0,115200 root=/dev/nfs ro ip=dhcp nfsroot=$nfsroot \$TAPPER_OPTIONS
END
        }

        my $installer_grub        =  $config->{installer_grub};
        $config->{installer_grub} =~
          s|\$TAPPER_OPTIONS|tapper_ip=$tapper_ip tapper_port=$tapper_port tapper_host=$tapper_host tapper_environment=$tapper_environment testrun=$testrun|g;

        return $config;
}

=head2 produce

Calls the producer for the given precondition

@param hash ref - config
@param hash ref - precondition

@return success - array ref containing preconditions
@return error   - error string

=cut

sub produce
{
        my ($self, $config, $precondition) = @_;
        my $producer = Tapper::Producer->new();
        my $retval = $producer->produce($self->testrun, $precondition);
        
        return $retval if not ref($retval) eq 'HASH';

        if ($retval->{topic}) {
                $self->testrun->topic_name($retval->{topic});
                $self->testrun->update;
        }
        my @precond_array = Load($retval->{precondition_yaml});
        return \@precond_array;
}


=head2 parse_produce_precondition

Parse a producer precondition, insert the produced ones and delete the
old one. In case of success the updated config and a list of new
precondition ids is returned.

@param hash ref                   - old config
@param precondition result object - precondition

@return success - (hash ref, array)
@return error   - (error string)

=cut

sub parse_produce_precondition
{
        my ($self, $config, $precondition) = @_;
        my $produced_preconditions = $self->produce($config, $precondition->precondition_as_hash);
        return $produced_preconditions 
          unless ref($produced_preconditions) eq 'ARRAY';
        my @precondition_ids;
        
        foreach my $produced_precondition (@$produced_preconditions) {
                my ($new_id) = model->resultset('Precondition')->add( [$produced_precondition] );
                push @precondition_ids, $new_id;
                my ($new_precondition) = model->resultset('Precondition')->find( $new_id );
                
                $config = $self->parse_precondition($config, $new_precondition);
                return $config unless ref($config) eq 'HASH';
        }
        return ($config, @precondition_ids);

}

=head2 parse_precondition

Parse a given precondition and update the config accordingly.

@param hash ref                   - old config
@param precondition result object - precondition

@return success - hash ref containing updated config
@return error   - error string

=cut

sub parse_precondition
{
        my ($self, $config, $precondition_result) = @_;
        my $precondition = $precondition_result->precondition_as_hash;

        my @precondition_ids = ($precondition_result->id);

        given($precondition->{precondition_type}){
                when('produce') {
                        ($config, @precondition_ids) = $self->parse_produce_precondition($config, $precondition_result);
                }
                when('image' ) {
                        $config = $self->parse_image_precondition($config, $precondition);
                }
                when( 'virt' ) {
                        $config=$self->parse_virt_preconditions($config, $precondition);
                }
                when( 'grub') {
                        $config = $self->parse_grub($config, $precondition);
                }
                when( 'installer_stop') {
                        $config->{installer_stop} = 1;
                }
                when( 'reboot') {
                        $config = $self->parse_reboot($config, $precondition);
                }
                when( 'autoinstall') {
                        $config = $self->parse_autoinstall($config, $precondition);
                }
                when( 'testprogram') {
                        $config = $self->parse_testprogram($config, $precondition);
                }
                when( 'testprogram_list') {
                        $config = $self->parse_testprogram_list($config, $precondition);
                }
                when( 'simnow' ) {
                        $config=$self->parse_simnow_preconditions($config, $precondition);
                }
                when( 'hint' ) {
                        $config=$self->parse_hint_preconditions($config, $precondition);
                }
                default {
                        push @{$config->{preconditions}}, $precondition;
                }
        }
                        
        push @{$config->{db_preconditions}}, @precondition_ids if $config;

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


        my $retval = $self->mcp_info->add_prc(0, $self->cfg->{times}{boot_timeout});
        return $retval if $retval;
        $config->{db_preconditions} = [];

 PRECONDITION:
        foreach my $precondition_result ( $self->testrun->ordered_preconditions) {
                $config = $self->parse_precondition($config, $precondition_result);
                # was not able to parse precondition and thus
                # return received error string
                if (not ref($config) eq 'HASH' ) {
                        return $config;
                }
        }


        $self->testrun->disassign_preconditions();
        $self->testrun->assign_preconditions(@{ $config->{db_preconditions} || [] });
        delete $config->{db_preconditions};

        # always have a PRC0 even without any test programs
        unless ($self->mcp_info->is_simnow() or $config->{prcs}) {
                $config->{prcs}->[0] = {testprogram_list => []};
        }

        # generate installer config
        $config = $self->update_installer_grub($config);

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
        my $testrun = $self->testrun;

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
        $config->{test_run}                  = $testrun->id;
        $config->{testrun_id}                = $testrun->id;

        if ($self->testrun->scenario_element) {
                $config->{scenario_id} = $self->testrun->scenario_element->scenario_id;
                my $path = $config->{paths}{sync_path}."/".$config->{scenario_id}."/";
                $config->{files}{sync_file} = "$path/syncfile";

                if ($self->testrun->scenario_element->peer_elements->first->testrun->id == $testrun->id) {
                        if (not -d $path) {
                                File::Path::mkpath($path, {error => \my $retval});
                        ERROR:
                                foreach my $diag (@$retval) {
                                        my ($file, $message) = each %$diag;
                                        #  $file might have been created by other scenario element between -d and mkpath
                                        # in this case ignore the error
                                        next ERROR if -d $file;
                                        return "general error: $message\n" if $file eq '';
                                        return "Can't create $file: $message";
                                }
                        }
                        my @peers = map {$_->testrun->testrun_scheduling->host->name} $self->testrun->scenario_element->peer_elements->all;
                        if (sysopen(my $fh, $config->{files}{sync_file}, O_CREAT | O_EXCL |O_RDWR )) {
                                print $fh $self->testrun->scenario_element->peer_elements->count;
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
        open (my $file, ">", $cfg_file)
          or return "Can't open config file $cfg_file for writing: $!";
        print $file $cfg;
        close $file;
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
