use Test::Deep;
use Test::More;
use Data::Dumper;

use aliased 'Artemis::Schema::TestrunDB::Result::Queue';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::WFQ';
use Artemis::Model 'model';
use Test::Fixture::DBIC::Schema;
use Artemis::Schema::TestTools;

construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_empty.yml' );

my $algorithm = Algorithm->new_with_traits ( traits => [WFQ], queues => {} );
ok($algorithm->does(WFQ), 'does WFQ');

my $q1 = model('TestrunDB')->resultset('Queue')->new({name => 'A', priority => 300, runcount => 0});
my $q2 = model('TestrunDB')->resultset('Queue')->new({name => 'B', priority => 200, runcount => 0});
my $q3 = model('TestrunDB')->resultset('Queue')->new({name => 'C', priority => 100, runcount => 0});

$q1->insert;
$q2->insert;
$q3->insert;

$algorithm->add_queue($q1);
$algorithm->add_queue($q2);
$algorithm->add_queue($q3);

my @order;

push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();

my $right_order=['A','B','A','A','B','C'];
my @order_names = map { $_->name } @order;
cmp_bag(\@order_names, $right_order, 'Scheduling');

done_testing;
