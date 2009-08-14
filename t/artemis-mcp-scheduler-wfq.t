use Test::Deep;
use Test::More tests => 2;
use Data::Dumper;

use aliased 'Artemis::MCP::Scheduler::Queue';
use aliased 'Artemis::MCP::Scheduler::Algorithm';
use aliased 'Artemis::MCP::Scheduler::Algorithm::WFQ';

my $scheduler = Algorithm->new_with_traits ( traits => [WFQ] );
ok($scheduler->does(WFQ), 'does WFQ');

$scheduler->add_queue(Queue->new(name => 'A', share => 300));
$scheduler->add_queue(Queue->new(name => 'B', share => 200));
$scheduler->add_queue(Queue->new(name => 'C', share => 100));

my $hostname = 'bullock';

my @order;

push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();
push @order, $scheduler->get_next_queue();

my $right_order=['A','B','A','A','B','C'];
my @order_names = map { $_->name } @order;
cmp_bag(\@order_names, $right_order, 'Scheduling');
