package Tapper::MCP::Net::Reset::PM211MIP;

use strict;
use warnings;

our $VERSION = '0.001';

use LWP::UserAgent;

sub reset_host
{
        my ($mcpnet, $host, $options) = @_;

        $mcpnet->log->info("Reboot via Infratec PM211MIP multi-socket outlet");

        my $ip       = $options->{ip};
        my $user     = $options->{user};
        my $passwd   = $options->{user};
        my $outletnr = $options->{outletnr}{$host};
        my $uri      = "http://$ip/sw?u=$user&p=$passwd&o=$outletnr&f=";
        my $uri_off  = $uri."off";
        my $uri_on   = $uri."on";

        my $ua = LWP::UserAgent->new;

        $mcpnet->log->info("turn off '$host' via $uri_off");
        my $response1 = $ua->get($uri_off)->decoded_content;

        my $sleep = 5;
        $mcpnet->log->info("sleep $sleep seconds");
        sleep $sleep;

        $mcpnet->log->info("turn on '$host' via $uri_on");
        my $response2 = $ua->get($uri_on)->decoded_content;

        my $error  = $response1 =~ /Done\./ && $response2 =~ /Done\./ ? 0 : 1;
        my $retval = $response1."\n".$response2;
        return ($error, $retval);
}

1;

__END__

=head1 NAME

Tapper::MCP::Net::Reset::PM211MIP - Reset via Infratec PM211MIP multi-socket outlet

=head1 DESCRIPTION

This is a plugin for Tapper.

It provides resetting a machine via the ethernet controllable PM211MIP
multi-socket outlet.

=head1

To use it add the following config to your Tapper config file:

 reset_plugin: PM211MIP
 reset_plugin_options:
   ip: 192.168.1.39
   user: admin
   passwd: secret
   outletnr:
     johnconnor: 1
     sarahconnor: 2

This configures Tapper MCP to use the PM211MIP plugin for reset and
gives it the configuration that the host C<johnconnor> is connected on
outlet number 0 and the host C<sarahconnor> on outlet number 1.

=head1 FUNCTIONS

=head2 reset_host ($mcpnet, $host, $options)

The primary plugin function.

It is called with the Tapper::MCP::Net object (for Tapper logging),
the hostname to reset and the options from the config file.
