use MooseX::Declare;
    
## no critic (RequireUseStrict)
class Tapper::MCP::Scheduler::Builder {

=head1 NAME
        
   Tapper::MCP::Scheduler::Builder - Generate Testruns

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS



=head1 FUNCTIONS

=head2 build

Create files needed for a testrun and put it into db.

@param string - hostname

@return success - testrun id

=cut
        
        method build(Str $hostname) {
                print "We are we are: The youth of the nation";
                return 0;
        }
}

{
        # just for CPAN
        package Tapper::MCP::Scheduler::Builder;
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
