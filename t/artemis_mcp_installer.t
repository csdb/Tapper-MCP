#!/usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use IO::Socket::INET;
use Log::Log4perl;
use Test::Fixture::DBIC::Schema;
use Test::MockModule;

use Artemis::Installer::Server;
use Artemis::Model 'model';
use Artemis::Schema::TestTools;

# for mocking
use Artemis::Config::Producer;
use Artemis::Net::Server;


use Test::More tests => 11;

BEGIN { use_ok('Artemis::Net::Server'); }

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


my $srv = new Artemis::Installer::Server;

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
        my $mock_producer = new Test::MockModule('Artemis::Config::Producer');
        $mock_producer->mock('create_config', sub { return (1,"create"); });
        my $producer = new Artemis::Config::Producer;
        my ($retval, $yaml) = $producer->create_config(4, 'install');
        is ($retval, 1, 'Mocking create_config');
        is ($yaml, 'create', 'Mocking create_config, yaml part');
        my $mock_srv = new Artemis::Installer::Server;
        $retval = $mock_srv->install(4, \*STDIN);
        is($retval, 'create', 'Install failing to get config');

        $mock_producer->mock('create_config', sub { return (0,"yaml"); });
        $mock_producer->mock('write_config', sub { return ("write"); });
        $producer = new Artemis::Config::Producer;
        $retval = $producer->write_config('install');
        is($retval, 'write','Mocking write_config');
        $retval = $mock_srv->install(4, \*STDIN);
        is($retval, 'write', 'Install failing to write config');

        my $mock_net = new Test::MockModule('Artemis::Net::Server');
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

