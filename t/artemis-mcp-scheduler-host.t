#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;
use Data::Dumper;

use aliased 'Artemis::Schema::TestrunDB::Result::Host';
use aliased 'Artemis::Model';

use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;

# --------------------------------------------------------------------------------
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# --------------------------------------------------------------------------------

use Test::More tests => 6;

my $host = Host->new({name => "iring"});
isa_ok($host, Host);

is($host->features->{cpus}[0]{model}, 3, "constructor iring.features.model");
is($host->features->{cpus}[0]{vendor}, "AMD", "constructor iring.features.vendor");

$host->name("bascha");
is($host->features->{cpus}[0]{model}, 67, "bascha.features.model");
#diag "bascha: ", Dumper($host->features);

$host->name("iring");
is($host->features->{cpus}[0]{model}, 3, "iring.features.model");
is($host->features->{cpus}[0]{vendor}, "AMD", "iring.features.vendor");
#diag "iring: ", Dumper($host->features);
diag "iring: ", $host->name;
