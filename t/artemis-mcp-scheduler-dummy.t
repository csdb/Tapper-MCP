use Test::Deep;
use Test::More tests => 2;
use Data::Dumper;
use Artemis::MCP::Scheduler::Algorithm::Dummy;
use Artemis::MCP::Scheduler::Queue;

my $scheduler = Artemis::MCP::Scheduler::Algorithm::Dummy->new();
isa_ok($scheduler, 'Artemis::MCP::Scheduler::Algorithm::Dummy');

$scheduler->add_queue(Artemis::MCP::Scheduler::Queue->new(name => 'A', share => 300));
$scheduler->add_queue(Artemis::MCP::Scheduler::Queue->new(name => 'B', share => 200));
$scheduler->add_queue(Artemis::MCP::Scheduler::Queue->new(name => 'C', share => 100));

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