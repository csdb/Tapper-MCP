#!/usr/bin/env perl

use strict;
use warnings;

use Class::C3;
use MRO::Compat;

use IO::Socket::INET;
use Log::Log4perl;
use POSIX ":sys_wait_h";
use Test::Fixture::DBIC::Schema;

use Artemis::Schema::TestTools;
use Test::More;

BEGIN { use_ok('Artemis::MCP::Child'); }


##############################################################
#                                                            #
# This test checks TAP handling in Artemis::MCP::Net::TAP.   #
# Artemis::MCP::Child already uses the role offered by this  #
# module so we test this instead of creating a separate      #
# module using the role.                                     #
#                                                            #
##############################################################

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------

# (XXX) need to find a way to include log4perl into tests to make sure no
# errors reported through this framework are missed
my $string = "
log4perl.rootLogger                               = INFO, root
log4perl.appender.root                            = Log::Log4perl::Appender::Screen
log4perl.appender.root.layout                     = SimpleLayout";
Log::Log4perl->init(\$string);

my $retval;
my $srv = Artemis::MCP::Child->new(4);



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

done_testing();
