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

use Test::More tests => 6;


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

