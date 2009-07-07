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

use Artemis::Model 'model';
use Artemis::Schema::TestTools;
use Artemis::Config;
use Artemis::MCP::Info;

# for mocking
use Artemis::MCP::Child;


use Test::More tests => 22;

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
if (ref($retval) eq 'HASH' ) {
        is($retval->{timeout}, 2, 'Timeout handling in get_message');
} else {
        is($retval, '','Expected a hash reference but got an error string, printing this string for your convenience');
}


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

#
# set_prc_state
#

my $mcp_info=Artemis::MCP::Info->new();
$mcp_info->add_prc(0, 5);
$mcp_info->add_prc(1, 5);
$mcp_info->add_testprogram(1, {timeout =>  5, name => "foo", argv => ['--bar']});
$mcp_info->add_testprogram(1, {timeout => 15, name => "foo", argv => ['--bar']});
$child->mcp_info($mcp_info);
$retval = $child->set_prc_state($mcp_info);
is_deeply($retval, [{start => 5, end => 60, timeouts => []},{start => 5, end => 60, timeouts => [ 5, 15]}] ,'Setting PRC state array');

#
# time_reduce
#
my $prc_state=[{start => 5, end => 60, timeouts => []},{start => 5, end => 60, timeouts => [ 5, 15]}];
my ($to_start, $to_stop) = (2,2);
($retval, $prc_state, $to_start, $to_stop )= $child->time_reduce(3, $prc_state, $to_start, $to_stop );
is_deeply($prc_state, [{start => 2, end => 60, timeouts => []},{start => 2, end => 60, timeouts => [ 5, 15]}],'Recalculation of PRC state during boot');
is($retval, 2, 'New timeout value after recalculation of PRC state during boot');


$prc_state = [{start=>0, timeouts => [], end=>97}, {start=>2, timeouts => [100], end=>100}, {start=>5, timeouts => [100,200], end=>100}];
($to_start, $to_stop) = (2,3);
($retval, $prc_state, $to_start, $to_stop )= $child->time_reduce(3, $prc_state, $to_start, $to_stop );
is_deeply($prc_state,
          [{start=>0, timeouts => [], end=>94},
           {start=>0, end=>0, results => [{error => 1, msg => "Guest 1: booting not finished in time, timeout reached"}]},
           {start=>2, timeouts=> [100,200], end=>100}] ,
          'Setting PRC state after timeout');
is($retval, 2, 'New timeout value after recalculation of PRC state after boot timeout');
is($to_start, 1, 'Recalculate number of guests to start after timeout');
is($to_stop, 2, 'Recalculate number of guests to start after timeout');


$prc_state = [{start=>0, timeouts=> [9], end=>9}, {start=>0, timeouts => [10,10], end=>10}, {start=>0, timeouts => [], end=>10}];
($to_start, $to_stop) = (0,3);
($retval, $prc_state, $to_start, $to_stop )= $child->time_reduce(20, $prc_state, $to_start, $to_stop );
is_deeply($prc_state, [{start=>0, end=>9, timeouts => [], results=>[{error => 1, msg => "Host: Testing not finished in time, timeout reached"}]},
                        {start=>0, end=>10, timeouts => [10], results => [{error => 1, msg => "Guest 1: Testing not finished in time, timeout reached"}]},
                        {start=>0, end=>0, results => [{error => 1,  msg => "Guest 2: Testing not finished in time, timeout reached"}]}] ,'Second test for setting PRC state after timeout');
is($to_start, 0, 'Second test for recalculate number of guests to start after timeout');
is($to_stop, 2, 'Second test for recalculate number of guests to stop after timeout');

#
# wait_for_systeminstaller
#
open $fh, "<","t/command_files/install-success.txt" or die "Can't open commands file installation with error:$!";
$closure = closure($fh);

$mock_child->mock('net_read', $closure);
# use eval to prevent waiting forever when test fails
eval {
        local $SIG{ALRM}=sub{die 'Parsing error in get_message did not return in time';};
        alarm(10);
        $retval = $child->wait_for_systeminstaller($fh);
};
alarm(0);
print STDERR $@ if $@;
is($retval, 0, 'Waiting for successful installation');
$mock_child->unmock('net_read');

#
# reboot test
#
$mcp_info=Artemis::MCP::Info->new();
$mcp_info->add_prc(0, 5);
$mcp_info->add_testprogram(0, {timeout => 15, name => "foo", argv => ['--bar']});
$mcp_info->set_max_reboot(0, 2);
$child->mcp_info($mcp_info);

my $pid=fork();
if ($pid==0) {
        sleep(2); #bad and ugly to prevent race condition
        open $fh, "<","t/command_files/reboot_success.txt" or die "Can't open commands file reboot test:$!";

        # get yaml and dump it instead of reading from file directly allows to have multiple messages in the file without need to parse seperators
        $closure = closure($fh);
        while (my $yaml = &$closure()) {
                msg_send(Dump($yaml), 1337);
        }
        exit 0;

} else {
        my $server = IO::Socket::INET->new(Listen    => 5,
                                           LocalPort => 1337);
        ok($server, 'Create socket');

        my @content;
        eval{
                $SIG{ALRM}=sub{die("timeout of 5 seconds reached while waiting for file upload test.");};
                alarm(5);
                $retval = $child->wait_for_testrun($server);
        };
        is($@, '', 'Get reboot messages in time');
        waitpid($pid,0);
        is_deeply($retval, [{'msg' => 'Test in PRC 0 started', 'error' => 0 },
                            {'msg' => 'Reboot 0', 'error' => 0 },
                            {'msg' => 'Reboot 1', 'error' => 0 },
                            {'msg' => 'Reboot 2', 'error' => 0 },
                            {'msg' => 'Test in PRC 0 finished', 'error' => 0 } ], 'Successful reboot test handling');}

#
# wait_for_testrun
#

$retval = $child->wait_for_testrun($pipe);
is_deeply($retval,[{msg => "Failed to boot test machine after timeout of $timeout seconds", error => 1}] , 'wait_for_testrun detects timeout while booting test machine');

#''''''''''''''''''''''''''''''''''''#
#                                    #
#   Full test through whole module   #
#                                    #
#''''''''''''''''''''''''''''''''''''#

# NOTE: assigning to $! has to be an error number, reading from $! will be the associated error string
$mock_inet->mock('new', sub { $!=1, return undef; });
$retval =  $child->runtest_handling('bullock');
like($retval, qr(Can't open socket for testrun 4:), "Catching unsuccessful socket creation");



$mock_inet->mock('new', sub { return $pipe; });
$retval =  $child->runtest_handling('bullock');
is ($retval, "Failed to boot Installer after timeout of $timeout seconds", 'Detect timeout during installer booting');
$mock_inet->original('new');



#
# generate_config for autoinstall
#
our @testconfigs;
$mock_conf->mock('write_config',sub{my ($self, $config, $file) = @_; push @testconfigs, {config => $config, file => $file}; return 0;});
$child      = Artemis::MCP::Child->new(100);
my $config  = $child->generate_configs('bullock',12);
is_deeply($testconfigs[1], {config => {'precondition_type' => 'testprogram',
                                       'program' => '/bin/uname_tap.sh',
                                       'runtime' => 30,
                                       'timeout' => 90},
                            file => "bullock-test-prc0"}, 'Create configs for autoinstall');




__END__
                Überlegungen zum Test
                =====================

Mockfunktionen, immer:
* Reboot
* IO::Socket::INET->new()


Normaler Ablauf Live:
* Socket erstellen - muss jeweils geöffnetes Filehandle zurückliefern
* install - wenn Fehler, dann TAP-Report -> mocken
** create config
** write config - tempfile schreiben oder mocken?
** write_grub_file - mocken oder umschreiben
** reboot - definitiv mocken
* wait_for_testrun
* tap_report -> immer noch mocken
* upload_files -> mocken

-> nach jedem state Ergebnis prüfen -> 9 Tests + Tests ob Mocking gewirkt hat

----------------------------------------------------
Tests transfered from old installer test
----------------------------------------------------


open my $fh, "<","t/commands_for_installer_server/success.txt" or die "Can't open commands file for successful installation:$!";
my $report = $srv->wait_for_systeminstaller(4, $fh);
close $fh;
is($report, 0, 'Waited for successful installation');


open $fh, "<","t/commands_for_installer_server/error.txt" or die "Can't open commands file installation with error:$!";
$report = $srv->wait_for_systeminstaller(4, $fh);
close $fh;
is($report, "Can't mount /data/bancroft", 'Waited for installation with error');

my $hardwaredb_systems_id = model('TestrunDB')->resultset('Testrun')->search({id => 4,})->first()->hardwaredb_systems_id;
my $hostname = $srv->get_hostname_for_hardware_id($hardwaredb_systems_id);
is($hostname, 'bullock', 'Getting hostname');


{
        my $mock_producer = new Test::MockModule('Artemis::MCP::Config');
        $mock_producer->mock('create_config', sub { return ("create"); });
        my $producer = new Artemis::MCP::Config;
        my $config = $producer->create_config(4, 'install');
        is ($config, 'create', 'Mocking create_config, yaml part');
        my $mock_srv = new Artemis::MCP::Installer;
        my $retval = $mock_srv->install(4, \*STDIN);
        is($retval, 'create', 'Install failing to get config');

        $mock_producer->mock('create_config', sub { return ({config => 'hash'}); });
        $mock_producer->mock('write_config', sub { return ("write"); });
        $producer = new Artemis::MCP::Config;
        $retval = $producer->write_config('install');
        is($retval, 'write','Mocking write_config');
        $retval = $mock_srv->install(4, \*STDIN);
        is($retval, 'write', 'Install failing to write config');

        my $mock_net = new Test::MockModule('Artemis::MCP::Net');
        $mock_producer->mock('write_config', sub { return (0); });
        $mock_net->mock('write_grub_file', sub { return "grub_file"; });
        $retval = $mock_srv->install(4, \*STDIN);
        is($retval, 'grub_file', 'Install failing to write grub config');

        $mock_net->mock('reboot_system', sub { return 0; });
        $mock_net->mock('write_grub_file', sub { return 0; });
        open my $fh, "<","t/commands_for_installer_server/success.txt" or die "Can't open commands file for successful installation:$!";
        my $report = $srv->install(4, $fh);
        close $fh;
        is($report, 0, 'Successful installation');


}

----------------------------------------------------
tests transfered from old net tests
----------------------------------------------------


open my $fh, "<","t/commands_for_net_server/one_prc.txt" or die "Can't open commands file for test one PRC:$!";
my $report = $srv->wait_for_testrun(4, $fh);
close $fh;
is_deeply($report, [{msg=>"All tests finished"}], 'Test with one PRC');


open $fh, "<","t/commands_for_net_server/two_prc.txt" or die "Can't open commands file for test two PRCs:$!";
$report = $srv->wait_for_testrun(4, $fh);
close $fh;
is_deeply($report, [{msg=>"All tests finished"}], 'Test with two PRCs');

open $fh, "<","t/commands_for_net_server/error.txt" or die "Can't open commands file for test with errors:$!";
$report = $srv->wait_for_testrun(4, $fh);
close $fh;
is_deeply($report, [{error => 1, msg => "Can't start xen guest described in /xen/images/001.svm"}], 'Test with errors');

open $fh, "<","t/commands_for_net_server/error_with_colon.txt" or die "Can't open command file for test with colon in error string:$!";
$report = $srv->wait_for_testrun(4, $fh);
close $fh;
is_deeply($report, [{error => 1, msg => "guest 1:Can't mount /data/bancroft/:No such file or directory"}], 'Test with colon in error string');

pipe(my $read, my $write) or die "Can't open pipe:$!";
$report = $srv->wait_for_testrun(4, $read);
close $fh;
is_deeply($report, [{error => 1, msg => "timeout for booting test system (5 seconds) reached."}], 'Test boot timeout for tests');


open $fh, "<","t/commands_for_net_server/error2.txt" or die "Can't open commands file for test with two PRCs and one error:$!";
$report = $srv->wait_for_testrun(4, $fh);
close $fh;
is_deeply($report, [{error => 1,
                     msg => "tried to execute /opt/artemis/testsuite/system/bin/artemis_testsuite_system.sh ".
                            "which is not an execuable or does not exist at all"},
                    {msg => "Test on guest 2"}], 'Test with two PRCs and one error');


