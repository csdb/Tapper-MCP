use MooseX::Declare;

# TODO: rename into "(Scheduler|Result)::Job"?
class Artemis::MCP::Scheduler::TestrunScheduling extends Artemis::Schema::TestrunDB::Result::TestrunScheduling
{
        use aliased 'Artemis::MCP::Scheduler::Host';
        use aliased 'Artemis::MCP::Scheduler::Queue';

        method match_host (ArrayRef $free_hosts)
        {

                foreach my $host ($self->requested_hosts->all)
                {
                        for (my $i = 0; $i <=  $#$free_hosts; $i++) {
                                if ($free_hosts->[$i]->{name} eq $host->hostname) {
                                        my $chosen_host = $free_hosts->[$i];
                                        my @free_hosts = @$free_hosts[0..$i-1, $i+1..$#$free_hosts];
                                        $free_hosts = \@free_hosts;
                                        return $chosen_host;
                                }
                        }
                }
                return;
        }

        # mem(4096);
        # mem > 4000;
        # TODO:
        sub _helper {
                my ($available, $subkey, $given) = @_;

                if ($given)
                {
                        # available
                        return
                            grep
                            {
                                    $given ~~ ($subkey ? $_->{$subkey} : $_)
                            } @{ $available };
                }
                else
                {
                        $subkey ? $available->[0]->{$subkey} : $available->[0];
                }
        }

        # vendor("AMD");        # with optional argument the value is checked against available features and returns the matching features
        # vendor eq "AMD";      # without argument returns the value
        # @_ means this optional param
        # $_ is some lines later the current context inside the for-loop where the eval happens
        sub mem(;$)      { _helper($_->features->{mem},      undef,      @_) }
        sub vendor(;$)   { _helper($_->features->{cpu},      'vendors',  @_) }
        sub family(;$)   { _helper($_->features->{cpu},      'family',   @_) }
        sub model(;$)    { _helper($_->features->{cpu},      'model',    @_) }
        sub stepping(;$) { _helper($_->features->{cpu},      'stepping', @_) }
        sub revision(;$) { _helper($_->features->{cpu},      'revision', @_) }
        sub socket(;$)   { _helper($_->features->{cpu},      'socket',   @_) }
        sub cores(;$)    { _helper($_->features->{cpu},      'cores',    @_) }
        sub clock(;$)    { _helper($_->features->{cpu},      'clock',    @_) }
        sub l2cache(;$)  { _helper($_->features->{cpu},      'l2cache',  @_) }
        sub l3cache(;$)  { _helper($_->features->{cpu},      'l3cache',  @_) }

        method match_feature($free_hosts)
        {
        HOST:
                foreach $host (@$free_hosts)
                {
                        $_ = $host;
                        foreach my $this_feature (@{$self->requested_features->all})
                        {
                                my $success = eval $this_feature->feature;
                                print STDERR "TestRequest.fits: ", $@ if $@;
                                next HOST if not $success;
                        }
                        return $host;
                }
                return;
        }

        method fits (ArrayRef $free_hosts)
        {
                if (not $free_hosts)
                {
                        return;
                }
                elsif ($self->hostnames)
                {
                        my $host = $self->match_host($free_hosts);
                        if ($host)
                        {
                                return $host;
                        }
                        elsif ($self->requested_features)
                        {
                                $host = $self->match_feature($free_hosts);
                                return $host if $host;
                        }
                        return;
                }
                elsif ($self->requested_features) # but no wanted hostnames
                {
                        $host = $self->match_feature($free_hosts);
                        return $host if $host;
                        return;
                }
                else # free_hosts but no wanted hostnames and no requested_features
                {
                        return shift @$free_hosts;
                }
        }
}

{
        # just for CPAN
        package Artemis::MCP::Scheduler::TestrunScheduling;
        our $VERSION = '0.01';
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

__END__

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

