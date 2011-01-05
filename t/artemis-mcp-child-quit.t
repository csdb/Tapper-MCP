#!/usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use IO::Socket::INET;
use MRO::Compat;
use Log::Log4perl;
use Test::Fixture::DBIC::Schema;
use Test::MockModule;
use YAML::Syck;
use Data::Dumper;

use Artemis::Model 'model';
use Artemis::Schema::TestTools;
use Artemis::Config;
use Artemis::MCP::Info;
use Artemis::MCP;

# for mocking
use Artemis::MCP::Child;


use Test::More;

sub msg_send
{
        my ($yaml, $port) = @_;
        my $remote = IO::Socket::INET->new(PeerHost => 'localhost',
                                           PeerPort => $port) or return "Can't connect to server:$!";
        print $remote $yaml;
        close $remote;
        return 0;
}

sub closure
{
        my ($file) = @_;
        my $i=0;
        my @data = LoadFile($file);
        return sub{my ($self, $file) = @_; return $data[$i++]};
}



# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# -----------------------------------------------------------------------------------------------------------------

# (XXX) need to find a way to include log4perl into tests to make sure no
# errors reported through this framework are missed
my $string = "
log4perl.rootLogger           = INFO, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout";
Log::Log4perl->init(\$string);


#''''''''''''''''''''''''''''''''''''#
#                                    #
#       Permanent mocking            #
#                                    #
#''''''''''''''''''''''''''''''''''''#

my $timeout = Artemis::Config->subconfig->{times}{boot_timeout};


my $mock_net = Test::MockModule->new('Artemis::MCP::Net');
$mock_net->mock('reboot_system',sub{return 0;});
$mock_net->mock('upload_files',sub{return 0;});
$mock_net->mock('write_grub_file',sub{return 0;});
$mock_net->mock('hw_report_send',sub{return 0;});

my $mock_conf = Test::MockModule->new('Artemis::MCP::Config');
$mock_conf->mock('write_config',sub{return 0;});

my $mock_inet     = Test::MockModule->new('IO::Socket::INET');
$mock_inet->mock('new', sub {my $original = $mock_inet->original('new'); return &$original(@_, LocalPort => 1337);});
                 
my $testrun    = 4;
my $mock_child = Test::MockModule->new('Artemis::MCP::Child');
my $child      = Artemis::MCP::Child->new($testrun);
my $retval;


my $mcp_info=Artemis::MCP::Info->new();
$mcp_info->add_prc(0, 5);
$mcp_info->add_testprogram(0, {timeout => 15, name => "foo", argv => ['--bar']});
$mcp_info->set_max_reboot(0, 2);
$child->mcp_info($mcp_info);

my $tap_report;
$mock_net->mock('tap_report_away', sub { (undef, $tap_report) = @_; return (0,0)});

my $pid=fork();
if ($pid==0) {
        sleep(2); #bad and ugly to prevent race condition
        $mock_inet->unmock('new');
        open my $fh, "<","t/command_files/quit_during_installation.txt" or die "Can't open commands file for quit test:$!";

        # get yaml and dump it instead of reading from file directly allows to have multiple messages in the file without need to parse seperators
        my $closure = closure($fh);
        while (my $yaml = &$closure()) {
                my $retval = msg_send(Dump($yaml), 1337);
                die $retval if $retval;
        }
        exit 0;
} else {
        eval{
                $SIG{ALRM}=sub{die("timeout of 7 seconds reached while waiting for 'quit in installer' test.");};
                alarm(7);
                $child->runtest_handling('bullock');
        };
        is($@, '', 'Get messages in time');
        waitpid($pid,0);
}

is($tap_report, "1..1
# Artemis-reportgroup-testrun: 4
# Artemis-suite-name: Topic-Software
# Artemis-suite-version: $Artemis::MCP::VERSION
# Artemis-machine-name: bullock
# Artemis-section: MCP overview
# Artemis-reportgroup-primary: 1
not ok 1 - Testrun canceled while waiting for installation start
# killed by admin
", 'Report for quit during installation');


$tap_report=q(Reset before running test 'quit during test execution');
$pid=fork();
if ($pid==0) {
        sleep(2); #bad and ugly to prevent race condition
        $mock_inet->unmock('new');
        open my $fh, "<","t/command_files/quit_during_test.txt" or die "Can't open commands file for quit test:$!";

        # get yaml and dump it instead of reading from file directly allows to have multiple messages in the file without need to parse seperators
        my $closure = closure($fh);
        while (my $yaml = &$closure()) {
                my $retval = msg_send(Dump($yaml), 1337);
                die $retval if $retval;
        }
        exit 0;
} else {
        eval{
                $SIG{ALRM}=sub{die("timeout of 7 seconds reached while waiting for 'quit in installer' test.");};
                alarm(7);
                $child->runtest_handling('bullock');
        };
        is($@, '', 'Get messages in time');
        waitpid($pid,0);
}

is($tap_report, "1..2
# Artemis-reportgroup-testrun: 4
# Artemis-suite-name: Topic-Software
# Artemis-suite-version: $Artemis::MCP::VERSION
# Artemis-machine-name: bullock
# Artemis-section: MCP overview
# Artemis-reportgroup-primary: 1
ok 1 - Installation finished
not ok 2 - Testrun canceled while running tests
# killed by admin
", 'Report for quit during installation');



done_testing();
