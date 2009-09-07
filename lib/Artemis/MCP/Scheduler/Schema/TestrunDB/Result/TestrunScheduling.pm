package Artemis::MCP::Scheduler::Schema::TestrunDB::Result::TestrunScheduling;



1;

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
