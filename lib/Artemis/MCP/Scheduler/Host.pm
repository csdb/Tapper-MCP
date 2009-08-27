use MooseX::Declare;

class Artemis::MCP::Scheduler::Host {

=head1 NAME

Host - Implements a host object used for scheduling

=head1 VERSION

Version 0.01

=head2 name

Hostname. Has to be unique.

=cut

        has name => (is => 'rw');

=head2 state

A host can have a certain state. Since it is not clear yet how to use
this attribute possible values are also unknown yet.

=cut

        has state => (is => 'rw');

=head2 features

List of features offered by a host. Can be used to decide whether a
certain host fits the requirement list of a test request.

=cut


        has available_features => (is => 'rw', isa => 'HashRef');


=head1 SYNOPSIS

 my $host = Artemis::MCP::Scheduler::Host->new
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
    );
 push @hostlist, $host;
 my $job = $controller->get_next_job(\@hostlist);

=head1 FUNCTIONS

=cut

}

{
    # just for CPAN
    package Artemis::MCP::Scheduler::Host;
    our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-wfq at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WFQ>.  I will be
notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of WFQ
