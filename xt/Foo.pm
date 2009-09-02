use MooseX::Declare;
class Foo {

        use aliased "Artemis::MCP::Scheduler::User";
        use Data::Dumper;

        method hello(User $u) {
                print STDERR Dumper($u);
                print "HELLO ", $u->hotstuff, "\n";
        }
}

1;
