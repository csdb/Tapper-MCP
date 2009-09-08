use MooseX::Declare;

use 5.010;

role Artemis::MCP::Scheduler::Algorithm::DummyAlgorithm {

        requires 'queues';

        has current_queue => (is => "rw");

        method get_next_queue()
        {
                my @Q = sort keys %{$self->queues};

                my %Q = map { $Q[$_] => $_ } 0..$#Q;

                if (not $self->current_queue) {
                        $self->current_queue( $self->queues->{$Q[0]} );
                        return $self->current_queue;
                }

                my $cur_name = $self->current_queue->name;
                my $new_pos = (($Q{$cur_name} || 0) + 1) % @Q;

                $self->current_queue( $self->queues->{$Q[$new_pos]} );
                return $self->current_queue;
        }
}

1; # End of Artemis::MCP::Scheduler::Algorithm::WFQ

__END__

=head1 NAME

DummyAlgorithm  - Dummy algorithm for testing

=head1 SYNOPSIS

Algorithm that returns queues in order it received it.

=head1 FUNCTIONS

=head2 get_next_queue

Evaluate which client has to be scheduled next.

@return success - client name;

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: proprietary


=cut

