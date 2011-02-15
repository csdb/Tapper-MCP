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
               'Artemis::MCP::Master',
               'Artemis::MCP::Net',
               'Artemis::MCP::Net::TAP',
               'Artemis::MCP::Startup',
               'Artemis::MCP::Scheduler::Algorithm',
               'Artemis::MCP::Scheduler::Algorithm::WFQ',
               'Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm',
               'Artemis::MCP::Scheduler::Builder',
               'Artemis::MCP::Scheduler::PreconditionProducer',
               'Artemis::MCP::Scheduler::Controller',
               'Artemis::MCP::Scheduler::PrioQueue',
              );

plan tests => $#modules+1;

foreach my $module(@modules) {
        require_ok($module);
}

diag( "Testing Artemis::MCP $Artemis::MCP::VERSION,Perl $], $^X" );
