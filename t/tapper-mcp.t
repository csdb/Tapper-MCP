#!/usr/bin/env perl

use strict;
use warnings;

# suppress some strange warnings
use Class::C3;
use MRO::Compat;

use Test::Fixture::DBIC::Schema;

use Tapper::Schema::TestTools;

use Test::More tests => 1;


BEGIN { use_ok('Tapper::MCP::Startup'); }

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------

#''''''''''''''''''''''''''''''''''''''#
#                                      #
#   Full test through all MCP modules  #
#                                      #
#''''''''''''''''''''''''''''''''''''''#

# coming soon
