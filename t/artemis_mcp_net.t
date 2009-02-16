#!/usr/bin/env perl

use strict;
use warnings;

use Class::C3;
use MRO::Compat;

use IO::Socket::INET;
use Log::Log4perl;
use POSIX ":sys_wait_h";
use Test::Fixture::DBIC::Schema;
use YAML::Syck;

use Artemis::MCP::Net;
use Artemis::Schema::TestTools;

use Test::More tests => 12;


BEGIN { use_ok('Artemis::MCP::Net'); }

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# -----------------------------------------------------------------------------------------------------------------

# (XXX) need to find a way to include log4perl into tests to make sure no
# errors reported through this framework are missed
my $string = "
log4perl.rootLogger                               = INFO, root
log4perl.appender.root                            = Log::Log4perl::Appender::Screen
log4perl.appender.root.layout                     = SimpleLayout";
Log::Log4perl->init(\$string);


my $srv = new Artemis::MCP::Net;

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


my $report_string = $srv->tap_report_create(4, [{msg => "Test on guest 1"},{error => 1, msg => "error"}]);
my $expect_string = '1..2
# Artemis-reportgroup-testrun: 4
# Artemis-suite-name: Topic-Software
# Artemis-suite-version: 1.0
# Artemis-machine-name: bullock
# Artemis-reportgroup-primary: 1
ok 1 - Test on guest 1
not ok 2 - error
';

is($report_string, $expect_string, 'TAP report creation');


my $pid=fork();
if ($pid==0) {
        sleep(2); #bad and ugly to prevent race condition
        my $retval = $srv->upload_files(23, 4, "install");
        
        # Can't make this a test since the test counter istn't handled correctly after fork
        die $retval if $retval;
        exit 0;
} else {
        my $server = IO::Socket::INET->new(Listen    => 5,
                                           LocalPort => Artemis::Config->subconfig->{report_api_port});
        ok($server, 'create socket');
        my $content;
        eval{
                $SIG{ALRM}=sub{die("timeout of 5 seconds reached while waiting for file upload test.");};
                alarm(5);
                my $msg_sock = $server->accept();
                while (my $line=<$msg_sock>) {
                        $content.=$line;
                }
                alarm(0);
        };
        is($@, '', 'Getting data from file upload');

        my $msg = "#! upload 23 install_prove plain\ncontent\n";
        is($content, $msg, 'File content from upload');

        waitpid($pid,0);
}
SKIP:{
        skip "since environment variable ARTEMIS_RUN_CONSERVER_TEST is not set", 1 unless $ENV{ARTEMIS_RUN_CONSERVER_TEST};
        my $console = $srv->conserver_connect('bullock');
        isa_ok($console, 'IO::Socket::INET','Console connected');
        $srv->conserver_disconnect($console);
}

