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

use Artemis::Schema::TestTools;
use Artemis::Config;

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
}

sub closure
{
        my ($file) = @_;
        my $i=0;
        my @data = LoadFile($file);
        return sub{my ($self, $file) = @_; return $data[$i++]};
}



BEGIN { use_ok('Artemis::MCP::Child'); }

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
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


my $mock_net = new Test::MockModule('Artemis::MCP::Net');
$mock_net->mock('reboot_system',sub{return 0;});
$mock_net->mock('tap_report_send',sub{return 0;});
$mock_net->mock('upload_files',sub{return 0;});
$mock_net->mock('write_grub_file',sub{return 0;});

my $mock_conf = new Test::MockModule('Artemis::MCP::Config');
$mock_conf->mock('write_config',sub{return 0;});

my $mock_inet     = new Test::MockModule('IO::Socket::INET');


my $testrun    = 4;
my $mock_child = Test::MockModule->new('Artemis::MCP::Child');
my $child      = Artemis::MCP::Child->new($testrun);
my $retval;

#''''''''''''''''''''''''''''''''''''#
#                                    #
#   Single functions tests           #
#                                    #
#''''''''''''''''''''''''''''''''''''#


#
# get_message()
#

my ($pipe, $fh, $dont_need);
pipe $pipe, $dont_need or die "Can't open pipe:$!";
# use eval to prevent waiting forever when test fails
eval {
        local $SIG{ALRM}=sub{die 'Timeout handling in get_message did not return in time'};
        alarm(10);
        $retval = $child->get_message($pipe, 2);
};
alarm(0);
is($@,'', 'Received message in time');
is($retval, undef, 'No message received in time at get_message()');


open $fh, "<","t/command_files/install-error.txt" or die "Can't open commands file installation with error:$!";
my $closure = closure($fh);
$mock_child->mock('net_read', $closure);


# use eval to prevent waiting forever when test fails
eval {
        local $SIG{ALRM}=sub{die 'Parsing error in get_message did not return in time';};
        alarm(10);
        $retval = $child->get_message($fh, 2);
};
alarm(0);
print STDERR $@ if $@;
is(ref $retval, 'HASH', 'Timeout handling in get_message');


#''''''''''''''''''''''''''''''''''''#
#                                    #
#   Full test through whole module   #
#                                    #
#''''''''''''''''''''''''''''''''''''#
my @tap_reports;
$mock_child->mock('tap_report_away', sub { my (undef, $new_tap_report) = @_; push @tap_reports, $new_tap_report; return (0,0)});


# NOTE: assigning to $! has to be an error number, reading from $! will be the associated error string
$mock_inet->mock('new', sub { $!=1, return undef; });
$retval =  $child->runtest_handling('bullock');
like($retval, qr(Can't open socket for testrun 4:), "Catching unsuccessful socket creation"); #'



$mock_inet->mock('new', sub { return $pipe; });
$retval =  $child->runtest_handling('bullock');
is($tap_reports[1], "1..1
# Artemis-reportgroup-testrun: 4
# Artemis-suite-name: Topic-Software
# Artemis-suite-version: $Artemis::MCP::VERSION
# Artemis-machine-name: bullock
# Artemis-section: MCP overview
# Artemis-reportgroup-primary: 1
not ok 1 - timeout hit while waiting for installer booting
", 'Detect timeout during installer booting');
$mock_inet->original('new');



done_testing();
