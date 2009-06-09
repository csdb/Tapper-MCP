use MooseX::Declare;

class Artemis::MCP::Scheduler::Queue {
        use Artemis::Exception::Param;

=head1 NAME
        
   Artemis::MCP::Scheduler::Queue - Object for test queue abstraction

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

=cut
        

        has name         => (is => 'rw', default => '');
        has producer     => (is => 'rw');
        has share        => (is => 'rw', isa => 'Num');
        has testrequests => (is => 'rw', isa => 'ArrayRef');
        has runcount     => (is => 'rw', default => 0); # WFQ specific

=head1 FUNCTIONS

=cut


#         method mem() {
#                 $host{mem};
#         }
        
        method compare_feature($feature) {
                my $tr = Artemis::MCP::Scheduler::TestRequest->new();
                $tr->hostnames(['bullock']);
                return $tr;
#                 # $feature = 'mem >= 8000';
#                 $host = $_;
#                 eval $feature;
        }        


=head2 get_test_request

Get a testrequest for one of the free hosts provided as parameter.

@param array ref - list of hostnames

@return success               - TestRequest
@return no fitting tr found   - 0

=cut

        method get_test_request(ArrayRef $free_hosts) {
                foreach my $host (@$free_hosts) {
                        my $testrequest = $self->compare_feature($host);
                        return $testrequest if $testrequest;
                }
        }

=head2 produce


Call the producer method associated with this object.

@param string - hostname

@return success - test run id
@return error   - exception

=cut

        method produce(Artemis::MCP::Scheduler::Host $host) {
                die Artemis::Exception::Param->new("Client ".$self->name."does not have an associated producer")
                    if not $self->producer ;
                return $self->producer->produce($host);
        }



}

{
        # just for CPAN
        package Artemis::MCP::Scheduler::Queue;
        our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

# Idea: provide functions that map to feature has

1;

