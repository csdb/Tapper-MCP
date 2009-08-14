use MooseX::Declare;

class Artemis::MCP::Scheduler::Job
{
        use aliased 'Artemis::MCP::Scheduler::Host';

        has testrunid => (is => 'rw');
        has host      => (is => 'rw', isa => Host);

}

{
        # just for CPAN
        package Artemis::MCP::Scheduler::Job;
        our $VERSION = '0.01';
}


=head1 NAME

Artemis::MCP::Scheduler::Job - Object to abstract a job handled by Scheduler

=head1 SYNOPSIS

=head1 Attributes

=head1 FUNCTIONS

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
