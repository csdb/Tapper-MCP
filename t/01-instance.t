#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use Test::More;

my @modules = ('Artemis::MCP', 
               'Artemis::MCP::Child',
               'Artemis::MCP::Control', 
               'Artemis::MCP::Config',
               'Artemis::MCP::Scheduler',
               'Artemis::MCP::Master',
               'Artemis::MCP::Net',
               'Artemis::MCP::Startup',

               'Artemis::MCP::Scheduler',
               'Artemis::MCP::Scheduler::Algorithm',
               'Artemis::MCP::Scheduler::Algorithm::WFQ',
               'Artemis::MCP::Scheduler::Builder',
               'Artemis::MCP::Scheduler::Host',
               'Artemis::MCP::Scheduler::Job',
               'Artemis::MCP::Scheduler::Producer',
               'Artemis::MCP::Scheduler::Queue',
               'Artemis::MCP::Scheduler::TestRequest',
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
        $obj = eval "$module->new(testrun => 4)";
        isa_ok($obj, $module);
        print $@ if $@;
        
        
}

diag( "Testing Artemis $Artemis::MCP::VERSION,Perl $], $^X" );
