use Test::Deep;
use Test::More tests => 5;
use Artemis::MCP::Scheduler::Algorithm::WFQ;
use Scheduler::Client;

my $scheduler = Artemis::MCP::Scheduler::Algorithm::WFQ->new();
isa_ok($scheduler, 'Artemis::MCP::Scheduler::Algorithm::WFQ');

$scheduler->add_client(Scheduler::Client->new('A'), 300);
$scheduler->add_client(Scheduler::Client->new('B'), 200);
$scheduler->add_client(Scheduler::Client->new('C'), 100);

my $hostname = 'bullock';

my @order;

push @order, $scheduler->schedule($hostname)->name;
push @order, $scheduler->schedule($hostname)->name;
push @order, $scheduler->schedule($hostname)->name;
push @order, $scheduler->schedule($hostname)->name;
push @order, $scheduler->schedule($hostname)->name;
push @order, $scheduler->schedule($hostname)->name;

my $right_order=['A','B','A','A','B','C'];
cmp_bag(\@order, $right_order, 'Scheduling');
