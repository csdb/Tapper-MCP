#!/usr/bin/env perl

use strict;
use warnings;

use Class::C3;
use MRO::Compat;

use IO::Socket::INET;
use Log::Log4perl;
use POSIX ":sys_wait_h";
use Test::Fixture::DBIC::Schema;
use String::Diff;
use Sys::Hostname;
use YAML::Syck;
use Cwd;
use TAP::DOM;

use Artemis::MCP::Net;
use Artemis::Schema::TestTools;

use Test::More tests => 12;
use Test::Deep;

BEGIN { use_ok('Artemis::MCP::Net'); }

my $hw_send_testrun_id=112;

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

my $retval;
my $srv = new Artemis::MCP::Net;

my $report_string = $srv->tap_report_create(4, [{msg => "Test on guest 1"},{error => 1, msg => "error"}]);
my $expect_string = '1..2
# Artemis-reportgroup-testrun: 4
# Artemis-suite-name: Topic-foobar
# Artemis-suite-version: 1.0
# Artemis-machine-name: bullock
# Artemis-section: MCP overview
# Artemis-reportgroup-primary: 1
ok 1 - Test on guest 1
not ok 2 - error
';

is($report_string, $expect_string, 'TAP report creation');


my $pid;
$pid=fork();
if ($pid==0) {
        sleep(2); #bad and ugly to prevent race condition
        $retval = $srv->upload_files(23, 4, "install");

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

#######################################
#
#        Test grub file handling
#
######################################
my $cwd = cwd();
$retval = $srv->copy_grub_file('bullock', $cwd.'/t/misc_files/source_grub.lst');
is($retval, 0, 'copy grub file');

my ($target, $source);
{
        open(SOURCE, "<","$cwd/t/misc_files/source_grub.lst") or die "Can't open $cwd/t/misc_files/source_grub.lst: $!";
        local $/;
        $source = <SOURCE>;
        close SOURCE;
}
{
        open(TARGET, "<",$srv->cfg->{paths}{grubpath}."bullock.lst") or die "Can't open ".$srv->cfg->{paths}{grubpath}."bullock.lst".": $!";
        local $/;
        $target = <TARGET>;
        close TARGET;
}

my ($old_string ,$new_string) = String::Diff::diff($source, $target, remove_open => '<del>',
             remove_close => '</del>',
             append_open => '<ins>',
             append_close => '</ins>', );
unlike($old_string, qr/<del>/, 'Nothing taken away from grub file while copy');
my $artemis_host = Sys::Hostname::hostname();
like($new_string, qr/<ins> artemis_host=$artemis_host artemis_ip=(\d{1,3}\.){3}\d{1,3}<\/ins>/, 'Artemis host added to grub file while copy');



$pid=fork();
if ($pid==0) {
        sleep(2); #bad and ugly to prevent race condition
        $retval = $srv->hw_report_send($hw_send_testrun_id);

        # Can't make this a test since the test counter istn't handled correctly after fork
        die $retval if $retval;
        exit 0;
} else {
        my $server = IO::Socket::INET->new(Listen    => 5,
                                           LocalPort => Artemis::Config->subconfig->{report_port},
                                           ReuseAddr => 1,
                                          );
        ok($server, 'create socket');
        my $content;
        eval{
                $SIG{ALRM}=sub{die("timeout of 5 seconds reached while waiting for send hw report tst.");};
                alarm(10);
                my $msg_sock = $server->accept();
                $msg_sock->print("15\n");   # send report id
                while (my $line=<$msg_sock>) {
                        $content.=$line;
                }
                alarm(0);
        };
        is($@, '', 'Getting data from hw_report_send');

        my $dom = TAP::DOM->new(tap => $content);
        is ($dom->{lines}[3]{_children}[0]{data}{network}[0]{vendor}, 'RealTek', 'Content from hw report');

        waitpid($pid,0);
}
