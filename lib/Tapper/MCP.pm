package Tapper::MCP;

use warnings;
use strict;

our $VERSION = '3.000001';

use Tapper::Config;
use Moose;

extends 'Tapper::Base';

sub cfg
{
        my ($self) = @_;
        return Tapper::Config->subconfig();
}

=head1 NAME

Tapper::MCP - Central control instance of Tapper automation part

=head1 SYNOPSIS

 use Tapper::MCP;

=cut

1;

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 BUGS

None.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tapper::MCP

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd

