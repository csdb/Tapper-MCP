package Tapper::MCP::Net::Reset::OSRC;

use strict;
use warnings;

sub reset_host
{
        my ($mcpnet, $host, $options) = @_;

        $mcpnet->log->info("Try reboot via reset switch");
        my $cmd = "/public/bin/osrc_rst_no_menu -f $host";
        $mcpnet->log->info("trying $cmd");
        my ($error, $retval) = $mcpnet->log_and_exec($cmd);
        return ($error, $retval);
}

1;

__END__

=head1 NAME

Tapper::MCP::Net::Reset::OSRC - Reset via OSRC reset script

=head1 DESCRIPTION

This is a plugin for Tapper.

It provides resetting a machine via the OSRC reset script (an internal
tool).

=head1

To use it add the following config to your Tapper config file:

 reset_plugin: OSRC
 reset_plugin_options:

This configures Tapper MCP to use the OSRC plugin for reset and
leaves configuration empty.

=head1 FUNCTIONS

=head2 reset_host ($mcpnet, $host, $options)

The primary plugin function.

It is called with the Tapper::MCP::Net object (for Tapper logging),
the hostname to reset and the options from the config file.
