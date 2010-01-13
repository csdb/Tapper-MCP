#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

# get rid of warnings
use Class::C3;
use MRO::Compat;
use Log::Log4perl;
use Test::Fixture::DBIC::Schema;
use Test::MockModule;

use Artemis::Model 'model';
use Artemis::Schema::TestTools;

use Artemis::MCP::Master;


use Test::More;
use Test::Deep;

BEGIN { use_ok('Artemis::MCP::Master'); }

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_scheduling.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# -----------------------------------------------------------------------------------------------------------------
my $mockmaster = Test::MockModule->new('Artemis::MCP::Master');
$mockmaster->mock('console_open',sub{use IO::Socket::INET;
                                     my $sock = IO::Socket::INET->new(Listen=>0);
                                     return $sock;});                                    
$mockmaster->mock('console_close',sub{return "mocked console_close";});

my $mockchild = Test::MockModule->new('Artemis::MCP::Child');
$mockchild->mock('runtest_handling',sub{my $self = shift @_; $self->rerun(1);return 0;});

my $mockschedule = Test::MockModule->new('Artemis::MCP::Scheduler');
$mockschedule->mock('get_next_testrun',sub{return('bullock',4)});


my $master   = Artemis::MCP::Master->new();
my $retval;

isa_ok($master, 'Artemis::MCP::Master');

$retval = $master->console_open();
isa_ok($retval, 'IO::Socket::INET', 'Mocking console_open');
$retval = $master->console_close();
is($retval, "mocked console_close", 'Mocking console_close');


$retval = $master->set_interrupt_handlers();
is($retval, 0, 'Set interrupt handlers');

$retval = $master->prepare_server();
is($retval, 0, 'Setting object attributes');
isa_ok($master->{readset}, 'IO::Select', 'Readset attribute');


$retval = $master->runloop(time());

my $job = model('TestrunDB')->resultset('TestrunScheduling')->find(101);
$job->status('schedule');
$job->testrun->rerun_on_error(2);
my @old_test_ids = map{$_->id} model('TestrunDB')->resultset('Testrun')->all;
$master->run_due_tests($job);
wait();
my @new_test_ids = map{$_->id} model('TestrunDB')->resultset('Testrun')->all;
cmp_bag([@old_test_ids, 3004], [@new_test_ids], 'New test because of rerun_on_error, no old test deleted');

done_testing();
