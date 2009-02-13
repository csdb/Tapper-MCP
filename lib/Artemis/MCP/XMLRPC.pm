package Artemis::MCP::XMLRPC;

use strict;
use warnings;

use RPC::XML;
use RPC::XML::Server;
use Method::Signatures;
use Data::Dumper;

use Moose;

with 'MooseX::Daemonize';

=head1 NAME

Artemis - Automatic Regression Test Environment and Measurement Instrument System

=head1 VERSION

Version 2.01

=head1 SYNOPSIS

 use Artemis::Install;

=head1 FUNCTIONS

=begin method

Declares a method.

=end method

=cut


has server => (is => 'rw');
has port   => (is => 'rw', isa => 'Int', default => 7357);

after start => sub {
                    my $self = shift;

                    return unless $self->is_daemon;

                    $self->initialize_server;
                    $self->server->server_loop;
                   }
;

=begin hello

Returns a hello string.

=end hello

=cut

method hello ($who)
{
        return "Hello, ".($who || "world"). "!";
}
;

=begin add

Returns sum of two arguments.

=end add

=cut

method add ($a, $b) { $a + $b };

=begin interface

Prints the description of available functions.

=end interface

=cut

method interface ($a, $b, $c)
{
        # --- debug output ---
        open LOG, ">>", "/tmp/twinserverxmlrpc.out" or die "Cannot open LOG";
        print LOG "ref self: ", Dumper(ref $self);
        print LOG "a: ", Dumper($a);
        print LOG "b: ", Dumper($b);
        print LOG "c: ", Dumper($c);
        close LOG;

        my $host = $self->server->{__host};
        my $port = $self->server->port;

        return "
STRING interface();
STRING hello();
INT    add (INT, INT);

(server: $host, port:   $port)
";
}
;


=begin register_api

Registers all available functions.

=end register_api

=cut

method register_api
{
        $self->server->add_proc({ name      => 'interface',
                                  signature => [ 'string string string string' ],
                                  code      => sub { $self->interface(@_) },
                                });
        $self->server->add_proc({ name      => 'add'  ,
                                  signature => [ 'int int int' ],
                                  code      => sub { $self->add (@_) },
                                });
        $self->server->add_proc({ name      => 'hello',
                                  signature => [ 'string', 'string string' ],
                                  code      => sub { $self->hello (@_) },
                                });
}
;

=begin initialize_server

Initializes the server and registers all functions.

=end initialize_server

=cut

method initialize_server
{
        $self->server(RPC::XML::Server->new(port => $self->port));
        $self->register_api();
}
;

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

