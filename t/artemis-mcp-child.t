#!/usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
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
use Artemis::Model 'model';

use Test::More;



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


my $mock_net = new Test::MockModule('Artemis::MCP::Net');
$mock_net->mock('reboot_system',sub{return 0;});
$mock_net->mock('tap_report_send',sub{return 0;});
$mock_net->mock('upload_files',sub{return 0;});
$mock_net->mock('write_grub_file',sub{return 0;});

my $mock_conf = new Test::MockModule('Artemis::MCP::Config');
$mock_conf->mock('write_config',sub{return 0;});


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

eval {
        local $SIG{ALRM}=sub{die 'Timeout handling in get_message did not return in time'};
        alarm(5);
        $retval = $child->get_message(1);
};
alarm(0);
is($@,'', 'get_message returned after timeout');
die "All remaining tests may sleep forever if timeout handling in get_message is broken"
  if $@ eq 'Timeout handling in get_message did not return in time'; 
is($retval, undef, 'No message due to timeout in get_message()');

my $message = model('TestrunDB')->resultset('Message')->new({testrun_id => 4, message =>  "state: start-install"});
$message->insert;

$retval = $child->get_message(1);
is_deeply($retval->message, {state => 'start-install'}, 'get_message() returns expected message');


#''''''''''''''''''''''''''''''''''''#
#                                    #
#   Full test through whole module   #
#                                    #
#''''''''''''''''''''''''''''''''''''#
my @tap_reports;
$mock_child->mock('tap_report_away', sub { my (undef, $new_tap_report) = @_; push @tap_reports, $new_tap_report; return (0,0)});



$retval =  $child->runtest_handling('bullock');
is($tap_reports[1], "1..1
# Artemis-reportgroup-testrun: 4
# Artemis-suite-name: Topic-Software
# Artemis-suite-version: $Artemis::MCP::VERSION
# Artemis-machine-name: bullock
# Artemis-section: MCP overview
# Artemis-reportgroup-primary: 1
not ok 1 - timeout hit while waiting for installation
", 'Detect timeout during installer booting');

done_testing();
