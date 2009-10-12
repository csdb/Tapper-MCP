#! /usr/bin/env perl

use strict;
use warnings;


# get rid of warnings
use Class::C3;
use MRO::Compat;


use Artemis::Model 'model';

use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;
use Artemis::MCP::Scheduler::PreconditionProducer::Kernel;
use Artemis::MCP::Scheduler::Job;
use Artemis::Config;

use Test::More;
use YAML;

# --------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_scheduling_run2.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# --------------------------------------------------------------------------------

Artemis::Config->subconfig->{package_dir}='t/misc_files/kernel_producer/';
qx(touch t/misc_files/kernel_producer/kernel/x86_64/file3);  # make sure file3 is the newest

my $job          = Artemis::MCP::Scheduler::Job->new();
my $producer     = Artemis::MCP::Scheduler::PreconditionProducer::Kernel->new();
my $precondition = $producer->produce($job, {});

is(ref $precondition, 'HASH', 'Producer / returned hash');

my $yaml = Load($precondition->{precondition_yaml});
is( $yaml->{precondition_type}, 'package', 'Precondition / precondition type');
is( $yaml->{filename}, 'kernel/x86_64/file3', 'Precondition / file name');

done_testing();
