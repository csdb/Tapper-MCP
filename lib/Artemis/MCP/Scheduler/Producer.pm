use MooseX::Declare;

    
class Artemis::MCP::Scheduler::Producer {
        use Artemis::MCP::Scheduler::Job;


=head1 NAME
        
   Artemis::MCP::Scheduler::Producer - Generate Testruns

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

Implements a test for weighted fair queueing scheduling algorithm.


=head1 FUNCTIONS

=head2 produce

Create files needed for a testrun and put it into db.

@param string - hostname

@return success - testrun id

=cut
        
        method produce(Artemis::MCP::Scheduler::Host $host) {
                my $job = Artemis::MCP::Scheduler::Job->new();
                return $job;
        }
}

{
        # just for CPAN
        package Artemis::MCP::Scheduler::Producer;
        our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of WFQ
