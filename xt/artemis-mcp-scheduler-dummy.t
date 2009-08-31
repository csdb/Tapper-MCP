use Test::Deep;
use Test::More tests => 2;
use Data::Dumper;
use aliased 'Artemis::MCP::Scheduler::Queue';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::Dummy';

my $scheduler = Algorithm->new_with_traits
    (
     traits => [Dummy]
    );
ok($scheduler->does(Dummy), 'does Dummy');

$scheduler->add_queue(Queue->new(name => 'A', priority => 300));
$scheduler->add_queue(Queue->new(name => 'B', priority => 200));
$scheduler->add_queue(Queue->new(name => 'C', priority => 100));

my @order;

push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();

my $right_order=['A','B','C','A','B','C'];
my @order_names = map { $_->name } @order;
is_deeply(\@order_names, $right_order, 'Scheduling');
