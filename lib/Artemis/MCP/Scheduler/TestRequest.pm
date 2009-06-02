use MooseX::Declare;

    
class Artemis::MCP::Scheduler::TestRequest {

=head1 NAME
        
   Artemis::MCP::Scheduler::TestRequest - Object that handles requesting new tests

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

=cut

=head2 features

List of features that a possible host for this test request should have. May be empty.

=cut 

has features => (is => 'rw', isa => 'ArrayRef');


=head2 

List of possible hosts for this test request. May be empty. 

=cut 

has hostnames => (is => 'rw', isa => 'ArrayRef');

=head2 

Name of the queue this test request goes into. Default is 'Adhoc'

=cut 

has hostnames => (is => 'rw', default => 'Adhoc');



=head1 FUNCTIONS

=cut

}        

{
        # just for CPAN
        package Artemis::MCP::Scheduler::Builder;
        our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of WFQ
