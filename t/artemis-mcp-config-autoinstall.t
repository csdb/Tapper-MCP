#! /usr/bin/env perl

use strict;
use warnings;

use Test::Fixture::DBIC::Schema;
use YAML::Syck;

use Artemis::Schema::TestTools;
use Artemis::MCP::Child;
use Artemis::Config;

use Test::More;
use Test::Deep;
use Test::MockModule;
use Sys::Hostname;
use Socket;

BEGIN { use_ok('Artemis::MCP::Config'); }


# (XXX) need to find a way to include log4perl into tests to make sure no
# errors reported through this framework are missed
my $string = "
log4perl.rootLogger           = INFO, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout";
Log::Log4perl->init(\$string);


sub msg_send
{
        my ($yaml, $port) = @_;
        my $remote = IO::Socket::INET->new(PeerHost => 'localhost',
                                           PeerPort => $port) or return "Can't connect to server:$!";
        print $remote $yaml;
        close $remote;
}

sub closure
{
        my ($file) = @_;
        my $i=0;
        my @data = LoadFile($file);
        return sub{my ($self, $file) = @_; return $data[$i++]};
}


# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_autoinstall.yml' );
# -----------------------------------------------------------------------------------------------------------------


my $producer = Artemis::MCP::Config->new(1);
isa_ok($producer, "Artemis::MCP::Config", 'Producer object created');

my $config = $producer->create_config(12);
is(ref($config),'HASH', 'Config created');


my $artemis_host = Sys::Hostname::hostname();
my $packed_ip    = gethostbyname($artemis_host);
fail("Can not get an IP address for artemis_host ($artemis_host): $!") if not defined $packed_ip;

my $artemis_ip   = inet_ntoa($packed_ip);

ok(defined $config->{installer_grub}, 'Grub for installer set');
is($config->{installer_grub}, 
   "title opensuse 11.2\n".
   "kernel /tftpboot/kernel autoyast=bare.cfg artemis_ip=$artemis_ip artemis_host=$artemis_host artemis_port=12 artemis_environment=test\n".
   "initrd /tftpboot/initrd\n",
   'Expected value for installer grub config');





#''''''''''''''''''''''''''''''''''''''''''''#
# When autoinstall started the installation  #
# MCP is supposed to provide a new grub file #
# for starting from hard disc.               #
# The following test checks whether this     #
# file is created correctly.                 #
#''''''''''''''''''''''''''''''''''''''''''''#
my $grubtext;
my $timeout = Artemis::Config->subconfig->{times}{boot_timeout};

my $mock_net = new Test::MockModule('Artemis::MCP::Net');
$mock_net->mock('reboot_system',sub{return 0;});
$mock_net->mock('tap_report_send',sub{return 0;});
$mock_net->mock('upload_files',sub{return 0;});
$mock_net->mock('write_grub_file',sub{(undef, undef, $grubtext) = @_;return 0;});
$mock_net->mock('hw_report_send',sub{return 0;});

my $mock_inet = new Test::MockModule('IO::Socket::INET');
$mock_inet->mock('new', sub{my $inet = bless {sockport => sub {return 12;}}; return $inet});

my $mock_child = Test::MockModule->new('Artemis::MCP::Child');
$mock_child->mock('get_message',sub{ return {state => 'start-install'}});


my $testrun    = 1;
my $child      = Artemis::MCP::Child->new($testrun);

my $retval = $child->runtest_handling('dickstone');
is($retval,
   qq(MCP expected state end-install or error-install but remote system is in state "start-install"),
   'runtesthandling returns because of mocked reboot');

is ($grubtext, 'timeout 2

title Boot from first hard disc
	chainloader (hd0,1)+1',
    'Grubfile written');

done_testing();
