use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Algorithm::Dummy extends Artemis::MCP::Scheduler::Algorithm {

        use Artemis::Exception;
        use Artemis::MCP::Scheduler::Queue;
        use TryCatch;
        use Data::Dumper;

=head1 NAME

  Dummy  - Dummy algorithm for testing

=head1 VERSION

Version 0.01

=cut


=head1 SYNOPSIS

Algorithm that returns queues in order it received it.

=head1 FUNCTIONS

=cut

=head2 add_queue

Add a queue to the attribute list

=cut

        method add_queue(Artemis::MCP::Scheduler::Queue $queue) {
                push(@{$self->queues}, $queue);
        }


=head2 get_next_queue

Evaluate which client has to be scheduled next.

@return success - client name;

=cut

        method get_next_queue() {
                my $queue = shift @{$self->queues};
                push(@{$self->queues}, $queue);
                return $queue;
        } 
}



=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: proprietary


=cut

1; # End of Artemis::MCP::Scheduler::Algorithm::WFQ
