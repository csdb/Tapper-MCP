#!/usr/bin/env perl
use strict;
use warnings;

use Test::Fixture::DBIC::Schema;
use Test::MockModule;
use Tapper::MCP::Child;
use Tapper::Schema::TestTools;

use Test::More;

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------

# (XXX) need to find a way to include log4perl into tests to make sure no
# errors reported through this framework are missed
my $string = "
log4perl.rootLogger           = INFO, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout";
Log::Log4perl->init(\$string);


my @commands;
my $mock_scp = Test::MockModule->new('Net::SCP');
my $mock_ssh = Test::MockModule->new('Net::SSH');
$mock_scp->mock('put', sub { my (undef, @params) = @_; push @commands, {put => \@params}; 1; });
$mock_ssh->mock('ssh', sub { my (@params) = @_; push @commands, {ssh => \@params}; 0;}); # Net::SSH doesn't offer OO interface

my $child = Tapper::MCP::Child->new(114);
my $retval = $child->generate_configs('nosuchhost');
is(ref $retval, 'HASH', 'Got config');

$child->start_testrun('nosuchhost', $retval);

# use Data::Dumper;
# diag Dumper \@commands;

is_deeply(shift @commands, 
          {
           'put' => [ '/data/tapper/live/repository/packages/tapperutils/opt-tapper64.tar.gz',
                      '/dev/shm/tmp/tapper-clientpkg.tgz'] },
          'Copy clientpackage');
is_deeply(shift @commands,
          {
           'ssh' => [{'args' => ['-xz', '-f /dev/shm/tmp/tapper-clientpkg.tgz', '-C /'],
                      'command' => 'tar',
                      'host' => 'nosuchhost'
                     }]},
          'Unpack client package');
is_deeply(shift @commands,
          {
           'ssh' => [{'args' => [ 'autoinstall'],
                      'command' => '/opt/tapper/bin/tapper-automatic-test.pl' ,
                      'host' => 'nosuchhost'
                     }]},
          'Start PRC in autoinstall mode');
          
done_testing();
