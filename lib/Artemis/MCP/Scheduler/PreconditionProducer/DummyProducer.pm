use MooseX::Declare;

## no critic (RequireUseStrict)
class Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer
  extends Artemis::MCP::Scheduler::PreconditionProducer
{
        method produce(Any $job, HashRef $precondition)
        {
                my $type = $precondition->{options}{type} || 'no_option';
                return {
                        precondition_yaml => "---\nprecondition_type: $type\n---\nprecondition_type: second\n",
                        topic => 'new_topic',
                       };

        }
}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer;
        our $VERSION = '0.01';
}

1;

__END__


=head1 NAME

Artemis::MCP::Scheduler::PreconditionProducer::DummyProducer - Dummy producer for testing

=head1 SYNOPSIS


=cut

=head2 features

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 OSRC SysInt Team, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
