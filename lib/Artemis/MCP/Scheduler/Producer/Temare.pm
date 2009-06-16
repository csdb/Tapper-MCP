use MooseX::Declare;

    
class Artemis::MCP::Scheduler::Producer::Temare extends Producer {

=head1 NAME
        
   Artemis::MCP::Scheduler::Producer::Temare - Wraps the existing temare producer

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS


=cut

=head2 features

=cut 

        method produce(Artemis::MCP::Scheduler::TestRequest $request) {
                return $request;
        }


}
{
        # just for CPAN
        package Artemis::MCP::Scheduler::Producer::Temare;
        our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
