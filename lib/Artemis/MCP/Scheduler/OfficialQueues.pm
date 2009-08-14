use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::OfficialQueues {

        use Artemis::MCP::Scheduler::Queue;
        use Artemis::Config;

        has queuelist => (is => 'ro',
                         isa => 'HashRef[Artemis::MCP::Scheduler::Queue]',
                         default => sub {
                                         no strict 'refs';
                                         my $env = Artemis::Config::_getenv;
                                         &{"get_queuelist_$env"};
                                        },
                        );

        # XXX TODO: create these lists from hardware db

        sub get_queuelist_development
        {
                say STDERR "get_queuelist_development";
                return {
                        Xen => Artemis::MCP::Scheduler::Queue->new (
                                                                    name     => 'Xen',
                                                                    share    => 300,
                                                                    producer => Artemis::MCP::Scheduler::Producer->new,
                                                                   ),
                        KVM => Artemis::MCP::Scheduler::Queue->new (
                                                                    name  => 'KVM',
                                                                    share => 200,
                                                                   ),
                        Kernel => Artemis::MCP::Scheduler::Queue->new (
                                                                       name  => 'Kernel',
                                                                       share => 10,
                                                                      ),
                       };
        }

        sub get_queuelist_live {
                say STDERR "get_queuelist_live";

                return {
                        Xen => Artemis::MCP::Scheduler::Queue->new (
                                                                    name     => 'Xen',
                                                                    share    => 300,
                                                                    producer => Artemis::MCP::Scheduler::Producer->new,
                                                                   ),
                        KVM => Artemis::MCP::Scheduler::Queue->new (
                                                                    name  => 'KVM',
                                                                    share => 200,
                                                                   ),
                        Kernel => Artemis::MCP::Scheduler::Queue->new (
                                                                       name  => 'Kernel',
                                                                       share => 10,
                                                                      ),
                       };
        }

        sub get_queuelist_test
        {
                say STDERR "get_queuelist_test";
                return {
                        Xen => Artemis::MCP::Scheduler::Queue->new ( 
                                                                    name     => 'Xen',
                                                                    share    => 300,
                                                                    producer => Artemis::MCP::Scheduler::Producer->new,
                                                                   ),
                        KVM => Artemis::MCP::Scheduler::Queue->new (
                                                                    name  => 'KVM',
                                                                    share => 200,
                                                                   ),
                        Kernel => Artemis::MCP::Scheduler::Queue->new (
                                                                       name  => 'Kernel',
                                                                       share => 10,
                                                                      ),
                       };
        }

}

{
    # Help the CPAN indexer
    package Artemis::MCP::Scheduler::OfficialQueues;
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

