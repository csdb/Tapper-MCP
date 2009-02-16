package Artemis::MCP::Startup;

use strict;
use warnings;

use Artemis::MCP::XMLRPC;
use Artemis::MCP::RunloopDaemon;

use Method::Signatures;

use Moose;

no strict 'refs';


=head1 NAME

Artemis::MCP - the central "Master Control Program"

=head1 SYNOPSIS

 use Artemis::MCP::Startup qw(:all);

=head1 FUNCTIONS

=begin method

Declares a method.

=end method

=begin start

Starts all registered daemons.

=end start

=begin stop

Stops all registered daemons.

=end stop

=begin restart

Restarts all registered daemons.

=end restart

=begin status

Prints status of all registered daemons.

=end status

=cut

has runloopdaemon => (is      => 'rw',
                      default => sub { new Artemis::MCP::RunloopDaemon ( pidfile => '/tmp/artemis_mcp_runloopdaemon.pid' ) }
                     );

has xmlrpc        => (is      => 'rw',
                      default => sub { new Artemis::MCP::XMLRPC ( pidfile => '/tmp/artemis_mcp_xmlrpc.pid' ) }
                     );

has servers       => ( is         => 'rw',
                       isa        => 'ArrayRef',
                       auto_deref => 1,
                     );

method start   { $_->start   foreach $self->servers };
method status  { $_->status  foreach $self->servers };
method restart { $_->restart foreach $self->servers };
method stop    { $_->stop    foreach $self->servers };

around 'new' => sub {
                     my ($new, @args) = @_;

                     my $self = $new->(@args);
                     $self->set_servers;
                     return $self;
                    };

=begin set_servers

Registers all handled daemons in an array.

=end set_servers

=cut

method set_servers
{
 $self->servers ([
#                  $self->xmlrpc,
                  $self->runloopdaemon,
                 ]);
};

=begin run

Dispatches the commandline command (start, stop, restart, status) to
all its daemons.

=end run

=cut

method run
{
        my ($command) = @ARGV;
        return unless $command && grep /^$command$/, qw(start status restart stop);
        local @ARGV;   # cleaner approach than changing @ARGV
        $self->$command;
#        print join (".\n", map { ref().": ".$_->status_message } $self->servers), ".\n";
};

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

