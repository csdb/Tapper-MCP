use MooseX::Declare;

    
class Artemis::MCP::Scheduler::TestRequest {
        use Artemis::MCP::Scheduler::Host;

=head1 NAME
        
   Artemis::MCP::Scheduler::TestRequest - Object that handles requesting new tests

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

  artemist-testrun new --request-feature='mem =< 8000'

=cut

=head2 features

List of features that a possible host for this test request should have. May be empty.

=cut 

        has requested_features => (is => 'rw', isa => 'ArrayRef');


=head2 

List of possible hosts for this test request. May be empty. 

=cut 

        has hostnames => (is => 'rw', isa => 'ArrayRef');

=head2

Name of the queue this test request goes into. Default is 'Adhoc'

=cut

        has queue => (is => 'rw', default => 'Adhoc');

=head2

Use this host for the test request. Will be set when the feature and host list
is evaluated.

=cut

        has on_host => (is => 'rw', isa => 'Artemis::MCP::Scheduler::Host');


=head1 FUNCTIONS

=cut 

=head2 match_host

Check whether any of the hosts requested by name matched any free host.

@param ArrayRef  - list free hosts

@return success  - host object
@return no match - 0

=cut

        method match_host (ArrayRef $free_hosts) {
                return 0 if not $self->hostnames;
                foreach my $hostname(@{$self->hostnames}) {
                        my ($host) = grep {$_->{name} eq $hostname} @$free_hosts;
                        return $host if $host;
                }
                return 0;
        }

=head2

Return associated feature of host object to use it in eval compare.

=cut

        sub Mem() {
                return $_->available_features->{Mem};
        }
        sub Vendor() {
                return $_->available_features->{Vendor};
        }
        sub Family() {
                return $_->available_features->{Family};
        }
        sub Model() {
                return $_->available_features->{Model};
        }
        sub Stepping() {
                return $_->available_features->{Stepping};
        }
        sub Revision() {
                return $_->available_features->{Revision};
        }
        sub Socket() {
                return $_->available_features->{Socket};
        }
        sub Number_of_cores() {
                return $_->available_features->{Number_of_cores};
        }
        sub Clock() {
                return $_->available_features->{Clock};
        }
        sub L2_Cache() {
                return $_->available_features->{L2_Cache};
        }
        sub L3_Cache() {
                return $_->available_features->{L3_Cache};
        }


=head2 fits

Checks whether this testrequests host or feature list fits any of the free
hosts.

@param ArrayRef - list of free hosts

@return success - this object with only the fitting host in the hostnames list
@return no fit  - 0

=cut

        method fits(ArrayRef $free_hosts) {
                return 0 if not $free_hosts;

                my $host = $self->match_host($free_hosts);
                if ($host) {
                        $self->on_host($host);
                        return $self;
                }

                return 0 if not $self->requested_features;
        HOST:
                foreach $host(@$free_hosts) {
                        $_ = $host;
                        foreach my $this_feature(@{$self->requested_features}) {
                                eval $this_feature or next HOST;
                        }
                        $self->on_host($host);
                        return $self;
                }
                return 0;
        }
}
{
        # just for CPAN
        package Artemis::MCP::Scheduler::TestRequest;
        our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
