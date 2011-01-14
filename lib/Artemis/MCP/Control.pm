package Artemis::MCP::Control;

use strict;
use warnings;

use Moose;
use Artemis::Config;

extends 'Artemis::MCP';

has testrun  => (is => 'rw');


=head1 NAME

Artemis::MCP::Control - Shared code for all modules that only handle one
                        specifid testrun

=head1 SYNOPSIS

 use Artemis::MCP::Control;

=head1 FUNCTIONS

=cut

around BUILDARGS => sub {
        my $orig  = shift;
        my $class = shift;
        
        if ( @_ >= 1 and not ref $_[0] ) {
                return $class->$orig({ testrun => $_[0] });
        }
        else {
                return $class->$orig(@_);
        }
}

1;

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 BUGS

None.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

 perldoc Artemis


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: restrictive
