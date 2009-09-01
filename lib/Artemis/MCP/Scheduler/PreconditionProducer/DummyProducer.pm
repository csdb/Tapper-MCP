use MooseX::Declare;

class Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer
    extends Artemis::MCP::Scheduler::PreconditionProducer
{
        use aliased 'Artemis::MCP::Scheduler::Job';
        use aliased 'Artemis::MCP::Scheduler::TestRequest';

        method produce(TestRequest $request)
        {
                my $job = Job->new();
                $job->host($request->on_host);
                return $job;
        }
}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::Producer::DummyProducer;
        our $VERSION = '0.01';
}

1;

__END__


=head1 NAME

Artemis::MCP::Scheduler::PreconditionProducer::Temare - Wraps the existing temare producer

=head1 SYNOPSIS


=cut

=head2 features

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
