#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

my @modules = ('Artemis::MCP', 
               'Artemis::MCP::Child',
               'Artemis::MCP::Control', 
               'Artemis::MCP::Config',
               'Artemis::MCP::Scheduler',
               'Artemis::MCP::Master',
               'Artemis::MCP::Net',
               'Artemis::MCP::Startup', 
              );
plan tests => $#modules+1;

foreach my $module(@modules) {
        require_ok($module);
}

diag( "Testing Artemis $Artemis::MCP::VERSION,Perl $], $^X" );
