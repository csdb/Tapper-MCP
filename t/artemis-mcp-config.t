#! /usr/bin/env perl

use strict;
use warnings;

use Test::Fixture::DBIC::Schema;
use YAML;

use Artemis::Schema::TestTools;

use Test::More;
use Test::Deep;

BEGIN { use_ok('Artemis::MCP::Config'); }


# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_xenpreconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------


my $producer = Artemis::MCP::Config->new(2);
isa_ok($producer, "Artemis::MCP::Config", 'Producer object created');

my $config = $producer->create_config(1235);     # expects a port number
is(ref($config),'HASH', 'Config created');

is($config->{preconditions}->[0]->{image}, "suse/suse_sles10_64b_smp_raw.tar.gz", 'first precondition is root image');

subbagof($config->{preconditions}, [
                                    {
                                     precondition_type => 'package',
                                     filename => "artemisutils/opt-artemis64.tar.gz",
                                    },
                                    {
                                     'artemis_package' => 'artemisutils/opt-artemis64.tar.gz',                                  
                                     'config' => {                                                                              
                                                  'runtime' => '5',                                                            
                                                  'test_program' => '/home/artemis/x86_64/bin/artemis_testsuite_kernbench.sh', 
                                                  'guest_number' => 1                                                          
                                                 },                                                                             
                                     'mountpartition' => undef,                                                                 
                                     'precondition_type' => 'prc',                                                              
                                     'mountfile' => '/kvm/images/raw.img'
                                     },
                                    {
                                     'config' => {                                                                              
                                                  'guests' => [                                                                
                                                               {                                                              
                                                                'exec' => '/usr/share/artemis/packages/mhentsc3/startkvm.pl' 
                                                               }                                                              
                                                              ],                                                               
                                                  'guest_count' => 1                                                           
                                                 },                                                                             
                                     'precondition_type' => 'prc'
                                    }],
         'Choosen subset of the expected preconditions');
                                    
is($config->{installer_stop}, 1, 'installer_stop');



my $info = $producer->get_mcp_info();
isa_ok($info, 'Artemis::MCP::Info', 'mcp_info');
my @timeout = $info->get_testprogram_timeouts(1);
is_deeply(\@timeout,[15],'Timeout for testprogram in PRC 1');

$producer = Artemis::MCP::Config->new(3);
$config = $producer->create_config();
is(ref($config),'HASH', 'Config created');
is($config->{preconditions}->[3]->{config}->{max_reboot}, 2, 'Reboot test');

$info = $producer->get_mcp_info();
isa_ok($info, 'Artemis::MCP::Info', 'mcp_info');
my $timeout = $info->get_boot_timeout(0);
is($timeout, 5, 'Timeout booting PRC 0');


#---------------------------------------------------

$producer = Artemis::MCP::Config->new(4);

$config = $producer->create_config(1337);   # expects a port number
is(ref($config),'HASH', 'Config created');

my $expected_grub = qr(timeout 2

title RHEL 5
kernel /tftpboot/stable/rhel/5/x86_64/vmlinuz  console=ttyS0,115200 ks=http://bancroft/autoinstall/stable/rhel/5/x86_64/artemis-ai.ks ksdevice=eth0 noapic artemis_ip=\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3} artemis_host=$config->{mcp_host} artemis_port=1337 artemis_environment=test
initrd /tftpboot/stable/rhel/5/x86_64/initrd.img
);

like($config->{installer_grub}, $expected_grub, 'Installer grub set by autoinstall precondition');

subbagof($config->{preconditions}, [
                                    {
                                     precondition_type => 'package',
                                     filename => "artemisutils/opt-artemis64.tar.gz",
                                    },
                                    {
                                     'artemis_package' => 'artemisutils/opt-artemis64.tar.gz',                                  
                                     'config' => {                                                                              
                                                  'runtime' => '5',                                                            
                                                  'test_program' => '/home/artemis/x86_64/bin/artemis_testsuite_kernbench.sh', 
                                                  'guest_number' => 1                                                          
                                                 },                                                                             
                                     'mountpartition' => undef,                                                                 
                                     'precondition_type' => 'prc',                                                              
                                     'mountfile' => '/kvm/images/raw.img'
                                     },
                                    {
                                     'config' => {                                                                              
                                                  'guests' => [                                                                
                                                               {                                                              
                                                                'exec' => '/usr/share/artemis/packages/mhentsc3/startkvm.pl' 
                                                               }                                                              
                                                              ],                                                               
                                                  'guest_count' => 1                                                           
                                                 },                                                                             
                                     'precondition_type' => 'prc'
                                    }],
         'Choosen subset of the expected preconditions');
                                    












done_testing();
