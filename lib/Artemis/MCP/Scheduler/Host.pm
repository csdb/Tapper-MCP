use MooseX::Declare;

class Artemis::MCP::Scheduler::Host {

        use aliased "Artemis::Model";

        # Hostname.
        has name  => (is => 'rw');
        has state => (is => 'rw'); # TODO: somewhat unclear. active(?)

        # List of features offered by a host.
        # Can be used to decide whether a certain host
        # fits the requirements of a test request.

        has features => (is      => 'rw',
                         isa     => 'HashRef',
                         builder => 'get_features',
                         #default => sub { &get_features },
                        );

        method get_features
        {
                # do not use accessor to prevent infinite recursion via `after name() {...}'
                my $name = $self->{name};

                my $features;
                if ($name)
                {
                        my $systems_id = Artemis::Model::get_systems_id_for_hostname($name);
                        $features = Artemis::Model::get_hardwaredb_overview($systems_id);
                }
                #use Data::Dumper;
                #say STDERR "get_features.features: ", Dumper($features);
                return $features;
        }

        after name {
                if (@_ > 1) # only setters
                {
                        say STDERR "* after name: ", join(", ", @_);
                        $self->features( $self->get_features );
                }
        };
}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::Host;
        our $VERSION = '0.01';
}

__END__

=head1 NAME

Host - Implements a host object used for scheduling

=head1 SYNOPSIS

 my $host = Artemis::MCP::Scheduler::Host->new
    (
     name               =>'bullock',
     state              => 'free',
     available_features => {
                            ...
                           },
    );
 push @hostlist, $host;
 my $job = $controller->get_next_job(\@hostlist);

=head1 FUNCTIONS

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
