package Artemis::MCP;

use warnings;
use strict;

our $VERSION = '2.000031';


use Artemis::Config;
use Artemis::Exception;
use Moose;

extends 'Artemis::Base';

sub cfg
{
        my ($self) = @_;
        return Artemis::Config->subconfig();
}

=head1 NAME

Artemis::MCP - Central control instance of Artemis automation part

=head1 SYNOPSIS

 use Artemis::MCP;

=cut

1;

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 BUGS

None.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Artemis::MCP

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: restrictive

