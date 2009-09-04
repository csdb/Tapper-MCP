use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::OfficialHosts {

        use aliased 'Artemis::MCP::Scheduler::Host';
        use Artemis::MCP::Scheduler::Model 'model';
        use Artemis::Config;

        has hostlist => (is      => 'ro',
                         isa     => 'ArrayRef['.Host.']',
                         builder => 'load_hostlist',
                        );

        # XXX TODO: create these lists from hardware db

        sub load_hostlist
        {
                my @hostlist;

                my $hosts_rs = model('TestrunDB')->resultset('Host')->search({});
                while (my $host = $hosts_rs->next) {
                        push @hostlist, Host->new({
                                                   name => $host->name,
                                                   # features are autoloaded
                                                  });
                }

                use Data::Dumper;
                print STDERR "hostlist: ", Dumper(\@hostlist);
                return \@hostlist;
        }
}

{
        # Help the CPAN indexer
        package Artemis::MCP::Scheduler::OfficialHosts;
        our $VERSION = '0.01';
}

1;

=pod

=head1 NAME

OfficialHosts - Lists of hosts official hosts used by Artemis if no
hardwaredb is available.

=head1 SYNOPSIS

 my $officialhosts = Artemis::MCP::Scheduler::OfficialHosts->new;
 #print Dumper($officialhosts->development);
 #print Dumper($officialhosts->live);
 #print Dumper($officialhosts->test);

=head1 VARIABLES

=head2 development

Fixed list of official hosts for development mode.

=head2 live

Fixed list of official hosts for live mode.

=head2 test

Fixed list of official hosts for test mode.

=head1 AUTHOR

OSRC SysInt team, C<< <osrc-sysint at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 OSRC SysInt team, all rights reserved.

=cut

