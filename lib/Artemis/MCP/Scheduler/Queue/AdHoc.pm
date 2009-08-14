use MooseX::Declare;

    
class Artemis::MCP::Scheduler::Queue::AdHoc extends Artemis::MCP::Scheduler::Queue {

=head1 NAME
        
   Artemis::MCP::Scheduler::Queue::AdHoc - AdHoc queue

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

=cut 

=head1 FUNCTIONS

=head2 produce

Call the producer method associated with this object.

@param string - hostname

@return success - test run id
@return error   - exception

=cut
        
        method produce(Artemis::MCP::Scheduler::Host $host) {
                my $job = Artemis::MCP::Scheduler::Job->new;
                return $job;
        }

        
}
{
    # just for CPAN
    package Artemis::MCP::Scheduler::Queue::AdHoc;
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

1; # End of Artemis::MCP::Scheduler::Queue::AdHoc
