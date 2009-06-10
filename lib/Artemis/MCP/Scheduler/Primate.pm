use MooseX::Declare;

    
class Artemis::MCP::Scheduler::Primate {
        use Artemis::Model 'model';
        use Artemis::MCP::Scheduler::Queue;
        use Artemis::MCP::Scheduler::TestRequest;

=head1 NAME
        
   Artemis::MCP::Scheduler::Primate - Main class of the scheduler

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

=cut 

        has hostlist  => (is => 'rw', isa => 'ArrayRef');
        has algorithm => (is => 'rw', isa => 'Artemis::MCP::Scheduler::Algorithm');


=head1 FUNCTIONS


=head2 get_prioritiy_job

Check priority queue for a new job and return it.

@return    job available - ad hoc queue object
@return no job available - 0

=cut

        method get_priority_job() {
                #                my $testruns=model('TestrunDB')->resultset('Testrun')->due_testruns();
                my $testruns;
                # do_someting in case the testrun exists;
                if ($testruns) {
                        my $queue = Artemis::MCP::Scheduler::Queue->new(name => 'AdHoc');
                        return $queue;
                }
                return 0;
        }

=head2 get_next_job

=cut
        
        method get_next_job(ArrayRef $free_hosts) {
                my $queue       = $self->get_priority_job();
                $queue          = $self->algorithm->get_next_queue() if not $queue;
                my $testrequest = $queue->get_test_request($free_hosts); # contains host decision
                my $job         = $queue->produce($testrequest->on_host);
                return $job;                                 # MCP maintains list of free hosts
        }
        
}
{
    # just for CPAN
    package Artemis::MCP::Scheduler::Primate;
    our $VERSION = '0.01';
}


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

1; # End of Artemis::MCP::Scheduler::Primate
