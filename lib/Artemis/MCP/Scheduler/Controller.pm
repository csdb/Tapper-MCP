use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Controller
{
        use Artemis::Model 'model';
        use Artemis::MCP::Scheduler::Queue;
        use Artemis::MCP::Scheduler::TestRequest;
        use aliased 'Artemis::MCP::Scheduler::Algorithm';

        has hostlist  => (is => 'rw', isa => 'ArrayRef');
        has algorithm => (is => 'rw',
                          isa => 'Artemis::MCP::Scheduler::Algorithm',
                          default => sub {
                                          Algorithm->new_with_traits
                                          (
                                           traits => ['Artemis::MCP::Scheduler::Algorithm::WFQ']
                                          );
                                         }
                         );

        method init() { }

        # method get_priority_job() {
        #         # my $testruns=model('TestrunDB')->resultset('Testrun')->due_testruns();

        #         my $testruns;
        #         # do_someting in case the testrun exists;
        #         if ($testruns) {
        #                 my $queue = Artemis::MCP::Scheduler::Queue->new(name => 'AdHoc');
        #                 return $queue;
        #         }
        #         return;
        # }

        method get_next_job(ArrayRef $free_hosts, %args) {
                my ($queue, $job);

                do {
                        use Data::Dumper;
                        $queue = $self->algorithm->get_next_queue() if not $queue;
                        print STDERR "controller loop: queue2: ", Dumper($queue);
                        print STDERR "controller loop: free_hosts: ", Dumper($free_hosts);
                        $job   = $queue->get_test_request($free_hosts); # contains host decision
                        print STDERR "controller loop: job: ", Dumper($job);
                        #sleep 3;
                } while (not $job and $args{try_until_found});

                return $job;    # MCP maintains list of free hosts
        }
}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::Controller;
        our $VERSION = '0.01';
}


=head1 NAME

Artemis::MCP::Scheduler::Controller - Main class of the scheduler

=head1 SYNOPSIS

=head1 FUNCTIONS

=head2 get_prioritiy_job

Check priority queue for a new job and return it.

@return    job available - ad hoc queue object
@return no job available - 0

=head2 get_next_job

Pick a testrequest and prepare it for execution. Returns 0 if not testrequest
fits any of the free hosts.

@param ArrayRef - array of host objects associated to hosts with no current test

@return success   - job object
@return no job    - 0

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-wfq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WFQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Artemis::MCP::Scheduler::Controller
