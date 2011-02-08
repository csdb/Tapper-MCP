use Test::Deep;
use Test::More tests => 2;
use Data::Dumper;
use aliased 'Tapper::Schema::TestrunDB::Result::Queue';
use aliased 'Tapper::MCP::Scheduler::Algorithm';
use aliased 'Tapper::MCP::Scheduler::Algorithm::DummyAlgorithm';

my $algorithm = Algorithm->new_with_traits
    (
     traits => [DummyAlgorithm],
     queues => {}, # set explicitely later
    );
ok($algorithm->does(DummyAlgorithm), 'does DummyAlgorithm');

$algorithm->add_queue(Queue->new({name => 'A', priority => 300}));
$algorithm->add_queue(Queue->new({name => 'B', priority => 200}));
$algorithm->add_queue(Queue->new({name => 'C', priority => 100}));

my @order;

push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();
push @order, $algorithm->get_next_queue();

my $right_order=['A','B','C','A','B','C'];
my @order_names = map { $_->name } @order;
is_deeply(\@order_names, $right_order, 'Scheduling');
