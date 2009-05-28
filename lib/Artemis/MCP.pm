package Artemis::MCP;

use warnings;
use strict;

our $VERSION = '2.000025';


use Artemis::Config;
use Moose;

with 'MooseX::Log::Log4perl';

=head2 log_and_exec

Execute a given command. Make sure the command is logged if requested and none
of its output pollutes the console. In scalar context the function returns 0
for success and the output of the command on error. In array context the
function always return a list containing the return value of the command and
the output of the command.

@param string - command

@return success - 0
@return error   - error string
@returnlist success - (0, output)
@returnlist error   - (return value of command, output)

=cut

sub log_and_exec
{
        my ($self, @cmd) = @_;
        my $cmd = join " ",@cmd;
        $self->log->debug( $cmd );
        my $output=`$cmd 2>&1`;
        my $retval=$?;
        if (not defined($output)) {
                $output = "Executing $cmd failed";
                $retval = 1;
        }
        chomp $output if $output;
        if ($retval) {
                return ($retval >> 8, $output) if wantarray;
                return $output;
        }
        return (0, $output) if wantarray;
        return 0;
}


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

