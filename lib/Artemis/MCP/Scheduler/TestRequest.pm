use MooseX::Declare;

class Artemis::MCP::Scheduler::TestRequest
{
        use aliased 'Artemis::MCP::Scheduler::Host';
        use aliased 'Artemis::MCP::Scheduler::Queue';
        use aliased 'Artemis::Schema::TestrunDB::Result::TestrunScheduling';

        has testrun            => (is => 'rw', isa => TestrunScheduling);
        has requested_features => (is => 'rw', isa => 'ArrayRef');
        has hostnames          => (is => 'rw', isa => 'ArrayRef');
        has queue              => (is => 'rw', isa => Queue);
        has on_host            => (is => 'rw', isa => Host);

        method match_host (ArrayRef $free_hosts)
        {
                return 0 if not $self->hostnames;
                foreach my $hostname(@{$self->hostnames})
                {
                        my ($host) = grep {$_->{name} eq $hostname} @$free_hosts;
                        return $host if $host;
                }
                return 0;
        }

        # TODO:
        sub _helper {
                my ($given, $subkey, $required) = @_;

                if ($required)
                {
                        return
                            grep
                            {
                                    $_ eq ($subkey ? $required->{$subkey} : $required)
                            } @{ $given };
                }
                else
                {
                        $subkey ? $given->[0]->{$subkey} : $given->[0];
                }
        }

# $VAR1 = {
#           'network' => [
#                          {
#                            'chipset' => 'rtl8169',
#                            'media' => 'RJ45',
#                            'mac' => '00:18:4d:76:7a:12',
#                            'bus_type' => 'PCI',
#                            'vendor' => 'RealTek'
#                          }
#                        ],
#           'mainboard' => undef,
#           'mem' => 4096,
#           'cpus' => [
#                       {
#                         'model' => '3',
#                         'l3cache' => undef,
#                         'cores' => undef,
#                         'socket' => undef,
#                         'revision' => 'B',
#                         'clock' => undef,
#                         'l2cache' => undef,
#                         'vendor' => 'AMD',
#                         'family' => '10',
#                         'stepping' => '2'
#                       }
#                     ]
#         };

        sub vendor(;$)   { _helper($_->features->{cpu}, 'vendors',  @_) }
        sub mem(;$)      { _helper($_->features->{mem}, undef,      @_) }
        sub family(;$)   { _helper($_->features->{cpu}, 'family',   @_) }
        sub model(;$)    { _helper($_->features->{cpu}, 'model',    @_) }
        sub stepping(;$) { _helper($_->features->{cpu}, 'stepping', @_) }
        sub revision(;$) { _helper($_->features->{cpu}, 'revision', @_) }
        sub socket(;$)   { _helper($_->features->{cpu}, 'socket',   @_) }
        sub cores(;$)    { _helper($_->features->{cpu}, 'cores',    @_) }
        sub clock(;$)    { _helper($_->features->{cpu}, 'clock',    @_) }
        sub l2cache(;$)  { _helper($_->features->{cpu}, 'l2cache',  @_) }
        sub l3cache(;$)  { _helper($_->features->{cpu}, 'l3cache',  @_) }

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


=head1 NAME

Artemis::MCP::Scheduler::TestRequest - Object that handles requesting
new tests

=head1 SYNOPSIS

  artemist-testrun new --request-feature='mem =< 8000'

=head2 features

List of features that a possible host for this test request should have. May be empty.

=head2

List of possible hosts for this test request. May be empty. 

=head2

Name of the queue this test request goes into. Default is 'Adhoc'

=head2

Use this host for the test request. Will be set when the feature and host list
is evaluated.

=head1 FUNCTIONS

=head2 match_host

Check whether any of the hosts requested by name matched any free host.

@param ArrayRef  - list free hosts

@return success  - host object
@return no match - 0

=head2

Return associated feature of host object to use it in eval compare.

=head2 fits

Checks whether this testrequests host or feature list fits any of the free
hosts.

@param ArrayRef - list of free hosts

@return success - this object with only the fitting host in the hostnames list
@return no fit  - 0

=head1 AUTHOR

OSRC SysInt team, C<< <osrc-sysint at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


1;
