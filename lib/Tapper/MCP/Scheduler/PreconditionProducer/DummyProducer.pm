use MooseX::Declare;

## no critic (RequireUseStrict)
class Tapper::MCP::Scheduler::PreconditionProducer::DummyProducer
  extends Tapper::MCP::Scheduler::PreconditionProducer
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
        package Tapper::MCP::Scheduler::PreconditionProducer::DummyProducer;
}

1;

__END__


=head1 NAME

Tapper::MCP::Scheduler::PreconditionProducer::DummyProducer - Dummy producer for testing

=head1 SYNOPSIS


=cut

=head2 features

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd
