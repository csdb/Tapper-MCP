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
               'Artemis::MCP::Scheduler::PreconditionProducer',
               'Artemis::MCP::Scheduler::Queue',
               'Artemis::MCP::Scheduler::TestRequest',
              );

plan tests => $#modules+1;

foreach my $module(@modules) {
        require_ok($module);
}

diag( "Testing Artemis $Artemis::MCP::VERSION,Perl $], $^X" );
