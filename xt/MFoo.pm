use MooseX::Declare;
class MFoo {

        use MUser;
        use Data::Dumper;

        method hello(MUser $u) {
                print STDERR Dumper($u);
                print "HELLO ", $u->hotstuff, "\n";
        }
}

1;
