#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use Test::More;
use Artemis::Schema::TestTools;
use Test::Fixture::DBIC::Schema;

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------


my @modules = ('Artemis::MCP', 
               'Artemis::MCP::Child',
               'Artemis::MCP::Control',
               'Artemis::MCP::Config',
               'Artemis::MCP::Master',
               'Artemis::MCP::Net',
               'Artemis::MCP::Startup',
               'Artemis::MCP::Scheduler::Algorithm',
               'Artemis::MCP::Scheduler::Builder',
               'Artemis::MCP::Scheduler::PreconditionProducer',
               'Artemis::MCP::Scheduler::Controller',
              );

my @roles = (
             'Artemis::MCP::Scheduler::Algorithm::WFQ',
             'Artemis::MCP::Scheduler::Algorithm::Dummy',
            );


plan tests => $#modules+1;

=pod

Using eval makes a bareword out of the $module string which is expected for
module handling. Some modules don't expect any parameter for new. They simply
ignore the 'testrun => 4'. Thus we don't need to separate both kinds of
modules.

=cut

foreach my $module(@modules) {
        my $obj;
        eval "require $module";
        $obj = eval "$module->new(testrun => 4, name => 'affe')";
        isa_ok($obj, $module);
        print $@ if $@;
}

diag( "Testing Tapper::MCP $Tapper::MCP::VERSION,Perl $], $^X" );

