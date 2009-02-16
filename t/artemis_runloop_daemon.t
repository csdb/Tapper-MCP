#! /usr/bin/env perl

use strict;
use warnings;


# get rid of warnings
use Class::C3;
use MRO::Compat;

use Log::Log4perl;

use Test::More tests => 7;
use Test::MockModule;

use Artemis::MCP::RunloopDaemon;

my $string='
log4perl.rootLogger           = INFO, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout';
Log::Log4perl->init(\$string);


pipe(my $pipe, my $pipewrite) or die "Can't open pipe:$!";

BEGIN { use_ok('Artemis::MCP::RunloopDaemon'); }

{
        my $mock_precond = new Test::MockModule('Artemis::MCP::Precondition');
        $mock_precond->mock('handle_preconditions', sub { return 'handle_preconditions'; });

        my $daemon = new Artemis::MCP::RunloopDaemon;
        my $retval = $daemon->runtest_handling(4, 'unknown',$pipe);
        is($retval, 'handle_preconditions', 'Runtest handling with failure in precondition handling');


        $mock_precond->mock('handle_preconditions', sub { return 0; });        
        my $mock_installer = new Test::MockModule('Artemis::Installer::Server');
        $mock_installer->mock('install', sub { return 'installer_install'; });
        my $installer = new Artemis::Installer::Server;
        $retval       = $installer->install(4, $pipe);
        is($retval, 'installer_install', 'Mocking install');

        $retval = $daemon->runtest_handling(4, 'unknown', $pipe);
        is($retval, 'installer_install', 'Runtest handling with failure in installation');
        $mock_installer->mock('install', sub { return 0;});        


        my $mock_net = new Test::MockModule('Artemis::Net::Server');
        $mock_net->mock('tap_report_send', sub { return(1, $_[2]);} );
        $mock_net->mock('wait_for_testrun', sub { return [{msg => "Installation successful"}];});

        # wait_for_testrun returns an array, check whether this is evaluated correctly
        $retval = $daemon->runtest_handling(4, 'unknown',$pipe);
        is_deeply($retval, [{msg => "Installation successful"}], 'Correct evaluation of wait_for_testrun return value');

        $mock_net->mock('tap_report_send', sub { return(0, 0);} );
        $mock_net->mock('upload_files', sub { return 'upload_files';} );        
        $retval = $daemon->runtest_handling(4, 'unknown',$pipe);
        is($retval, 'upload_files', 'Runtest handling with failure in file upload');

        $mock_net->mock('upload_files', sub { return 0;} );
        $retval = $daemon->runtest_handling(4, 'unknown',$pipe);
        is($retval, 0, 'Runtest handling finished successfully');

    



}


