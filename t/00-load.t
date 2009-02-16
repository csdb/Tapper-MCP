#! /usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;

BEGIN {
        use_ok( 'Artemis::MCP' );
        use_ok( 'Artemis::MCP::Config' );
        use_ok( 'Artemis::MCP::Installer' );
        use_ok( 'Artemis::MCP::Net' );
        use_ok( 'Artemis::MCP::RunloopDaemon' );
        use_ok( 'Artemis::MCP::Startup' );
        use_ok( 'Artemis::MCP::XMLRPC' );
}

diag( "Testing Artemis $Artemis::VERSION, Perl $], $^X" );
