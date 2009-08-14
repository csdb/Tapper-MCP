use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::OfficialHosts {

        use aliased 'Artemis::MCP::Scheduler::Host';
        use Artemis::Config;

        has hostlist => (is => 'ro',
                         isa => 'ArrayRef['.Host.']',
                         default => sub {
                                         no strict 'refs';
                                         my $env = Artemis::Config::_getenv;
                                         &{"get_hostlist_$env"};
                                        },
                        );

        # XXX TODO: create these lists from hardware db

        sub get_hostlist_development {
                say STDERR "get_hostlist_development";
                [ ];
        }

        sub get_hostlist_live
        {
                say STDERR "get_hostlist_live";
                [ ];
        }

        sub get_hostlist_test
        {
                say STDERR "get_hostlist_test";
                [
                 Host->new
                 (
                  name               =>'bullock',
                  state              => 'free',
                  available_features => {
                                         Mem             => 8192,
                                         Vendor          => 'AMD',
                                         Family          => 15,
                                         Model           => 67,
                                         Stepping        => 2,
                                         Revision        => '',
                                         Socket          => 'AM2',
                                         Number_of_cores => 2,
                                         Clock           => 2600,
                                         L2_Cache        => 1024,
                                         L3_Cache        => 0
                                        },
                 ),
                 Host->new
                 (
                  name               => 'dickstone',
                  state              => 'free',
                  available_features => {
                                         Mem             => 4096,
                                         Vendor          => 'AMD',
                                         Family          => 15,
                                         Model           => 67,
                                         Stepping        => 2,
                                         Revision        => '',
                                         Socket          => 'AM2',
                                         Number_of_cores => 2,
                                         Clock           => 2600,
                                         L2_Cache        => 1024,
                                         L3_Cache        => 0
                                        },
                 ),
                ];
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
 print Dumper($officialhosts->development);
 print Dumper($officialhosts->live);
 print Dumper($officialhosts->test);

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

