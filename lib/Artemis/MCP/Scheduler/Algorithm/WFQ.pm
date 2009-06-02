use MooseX::Declare;

    
class Artemis::MCP::Scheduler::Algorithm::WFQ {
        use Scheduler::Exception;
        use Scheduler::Client;
        use TryCatch;

=head1 NAME
        
  WFQ - Weighted Fair Queueing!

=head1 VERSION

Version 0.01

=cut


        has clients        => (is      => 'rw',
                               isa     => 'HashRef',
                               default => sub {{}},
                              );


=head1 SYNOPSIS

Implements a test for weighted fair queueing scheduling algorithm.


=head1 FUNCTIONS

=cut

=head2 get_virtual_finishing_time

Return the virtual finishing time of a given client

@param string - client

@return success - virtual time
@return error   - error string

=cut

        method get_virtual_finishing_time(Str $name)
        {
                die Exception::Param->new(qq("$name" is not a valid client name)) if not $self->clients->{$name};
                return ($self->clients->{$name}->{runcount} + 1.0) / $self->clients->{$name}->{share};
        }

=head2 add_client

Add a new client to the scheduler.

@param Scheduler::Client - name of the client has to be unique
@param int               - proportional share

@return success - 0
@return error   - error string

=cut

        method add_client(Scheduler::Client $client, Num $share where {$_ > 0 })
        {
                foreach my $client (keys %{$self->clients}) {
                        $self->clients->{$client}->{runcount} = 0;
                }
                my $name = $client->name;

                $self->clients->{$name}->{share}  = $share;
                $self->clients->{$name}->{object} = $client;
                $self->clients->{$name}->{runcount} = 0;
                return 0;
        }

=head2 remove_client

Remove a client from scheduling

@param string - name of the client to be removed

@return success - 0
@return error   - error string

=cut

        method remove_client(Str $name)
        {
                die Exception::Param->new(qq("$name" is not in the client list)) if not $self->clients->{$name};
                delete $self->clients->{$name};
                return 0;
        }

=head2 update_client

Update the time entry of the given client

@param string - name of the client

@return success - 0

=cut

        method update_client(Str $name)
        {
                die Exception::Param->new(qq("$name" is not a valid client name)) if not $self->clients->{$name};
                $self->clients->{$name}->{runcount} += 1;
                return 0;
        }


=head2 schedule

Evaluate which client has to be scheduled next.

@param string - get a testrun for this host

@return success - client name;

=cut

        method schedule(Str $hostname)
        {
                my $vft;
                my $client;
                foreach my $this_client (keys %{$self->clients}) {
                        my $this_vft;

                        try { 
                                $this_vft = $self->get_virtual_finishing_time($this_client);
                        }
                          catch($e) {
                                  die ($e->msg," at ", $e->line,"\n");

                          }
                        if (not defined $vft) {
                                $vft = $this_vft;
                                $client = $this_client;
                        } else {
                                if ($vft > $this_vft) {
                                        $vft = $this_vft;
                                        $client = $this_client;
                                }
                        }
                }
                $self->update_client($client);
                return $self->clients->{$client}->{object};
        }
}

{
    # just for CPAN
    package WFQ;
    our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-wfq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WFQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of WFQ
