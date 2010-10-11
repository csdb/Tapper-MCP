package Artemis::MCP::Net::Reset::OSRC;

use strict;
use warnings;

sub reset_host
{
        my ($self, $host, $options) = @_;
        
        $self->log->info("Try reboot via reset switch");
        my $cmd = "/public/bin/osrc_rst_no_menu -f $host";
        $self->log->info("trying $cmd");
        my ($error, $retval) = $self->log_and_exec($cmd);
        return ($error, $retval);
}

1;
