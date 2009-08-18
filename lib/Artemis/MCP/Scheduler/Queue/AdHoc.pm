use MooseX::Declare;

class Artemis::MCP::Scheduler::Queue::AdHoc extends Artemis::MCP::Scheduler::Queue
{
        use aliased 'Artemis::MCP::Scheduler::Host';
        use aliased 'Artemis::MCP::Scheduler::Job';

        method produce(Host $host)
        {
                my $job = Job->new;
                return $job;
        }
}

{
    # just for CPAN
    package Artemis::MCP::Scheduler::Queue::AdHoc;
    our $VERSION = '0.01';
}

1;

__END__


=head1 NAME

Artemis::MCP::Scheduler::Queue::AdHoc - AdHoc queue

=head1 SYNOPSIS

=cut 

=head1 FUNCTIONS

=head2 produce

Call the producer method associated with this object.

@param string - hostname

@return success - test run id
@return error   - exception

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

