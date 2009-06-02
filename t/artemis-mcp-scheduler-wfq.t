use Test::Deep;
use Test::More tests => 2;
use Data::Dumper;
use Artemis::MCP::Scheduler::Algorithm::WFQ;
use Artemis::MCP::Scheduler::Queue;

my $scheduler = Artemis::MCP::Scheduler::Algorithm::WFQ->new();
isa_ok($scheduler, 'Artemis::MCP::Scheduler::Algorithm::WFQ');

diag "Queues VORHER: ", Dumper($scheduler->queues);
$scheduler->add_queue(Artemis::MCP::Scheduler::Queue->new(name => 'A', share => 300));
$scheduler->add_queue(Artemis::MCP::Scheduler::Queue->new(name => 'B', share => 200));
$scheduler->add_queue(Artemis::MCP::Scheduler::Queue->new(name => 'C', share => 100));
diag "Queues NACHHER: ", Dumper($scheduler->queues);

my $hostname = 'bullock';

my @order;

push @order, $scheduler->schedule($hostname);
push @order, $scheduler->schedule($hostname);
push @order, $scheduler->schedule($hostname);
push @order, $scheduler->schedule($hostname);
push @order, $scheduler->schedule($hostname);
push @order, $scheduler->schedule($hostname);

my $right_order=['A','B','A','A','B','C'];
cmp_bag(\@order, $right_order, 'Scheduling');
