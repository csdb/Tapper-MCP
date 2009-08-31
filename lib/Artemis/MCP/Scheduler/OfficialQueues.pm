use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::OfficialQueues {

        use aliased 'Artemis::MCP::Scheduler::Queue';
        use aliased 'Artemis::MCP::Scheduler::PreconditionProducer';
        use Artemis::Model 'model';

        has queuelist => (is     => 'ro',
                         isa     => 'HashRef['.Queue.']',
                         default => sub { &load_queuelist },
                        );

        # XXX TODO: create these lists from hardware db

        sub load_queuelist
        {
                no strict 'refs';
                my $queue_rs = model('TestrunDB')->resultset('Queue')->search({});
                my %queues;
                foreach ($queue_rs->all) {
                        my %producer;
                        if ($_->producer) {
                                my $producer_class = "Artemis::MCP::Scheduler::PreconditionProducer::".$_->producer;
                                eval "use $producer_class";
                                %producer = (producer => $producer_class->new ) unless $@;
                        }
                        $queues{$_->name} = Queue->new ( id       => $_->id,
                                                         name     => $_->name,
                                                         priority => $_->priority,
                                                         %producer,
                                                       );
                }

                return \%queues;
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
 #print Dumper($officialhosts->queuelist);

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

