use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::Queue
{
        use Artemis::Exception::Param;
        use aliased 'Artemis::MCP::Scheduler::TestRequest';
        use aliased 'Artemis::MCP::Scheduler::PreconditionProducer';

        has name         => (is => 'rw', isa => 'Str',                default => '',         required => 1);
        has producer     => (is => 'rw', isa => PreconditionProducer                                      );
        has testrequests => (is => 'rw', isa => 'ArrayRef',           default => sub { [] },              );

        has priority     => (is => 'rw', isa => 'Num'                                                     );
        has runcount     => (is => 'rw', isa => 'Num',                default => 0                        );

        method get_test_request (ArrayRef $free_hosts)
        {
                foreach my $testrequest(@{$self->testrequests})
                {
                        if ($testrequest->fits( $free_hosts ))
                        {
                                my $job = $self->produce( $testrequest );
                                return $job;
                        }
                }
                return;
        }

        method produce (TestRequest $request)
        {
                if (not $self->producer) {
                        die Artemis::Exception::Param->new
                            ("Queue ".$self->name." does not have an associated producer");
                }
                return $self->producer->produce($request);
        }

}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::Queue;
        our $VERSION = '0.01';
}

__END__

=head1 NAME

Artemis::MCP::Scheduler::Queue - Object for test queue abstraction

=head1 SYNOPSIS

=head1 FUNCTIONS

=head2 get_test_request

Get a testrequest for one of the free hosts provided as parameter.

@param array ref - list of hostnames

@return success               - Job
@return no fitting tr found   - 0

=head2 produce


Call the producer method associated with this object.

@param string - hostname

@return success - test run id
@return error   - exception



=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

# Idea: provide functions that map to feature has

1;

