package Artemis::MCP::Precondition;

use strict;
use warnings;

use Method::Signatures;
use Moose;

use Artemis;
use Artemis::Model 'model';
use Artemis::Builder;
use Artemis::Image;
use Artemis::Installer::Server;

=head1 NAME

Artemis::MCP::Precondition - Check all preconditions for a specific test run and fullfill those that are not met yet

=head1 SYNOPSIS

 use Artemis::MCP::Precondition;


=cut 


=head1 FUNCTIONS

=head2 handle_preconditions

Check which preconditions exist for a given testrun, evaluate which ones are
not fullfilled and call the appropriate tools to fullfill them.

@param int - testrun id

@return success - 0
@return error   - error string

=cut

method handle_preconditions($testrun)
{
        my $search = model('TestrunDB')->resultset('Testrun')->search({id => $testrun,})->first();
        my @ordered_preconditions = $search->ordered_preconditions if $search;
        my @filtered_precondition = grep { $_->precondition_as_hash->{precondition_type} =~ /^image|package$/ } @ordered_preconditions;

        for (my $i=0; $i<=$#filtered_precondition;$i++) {
                my $condition=$filtered_precondition[$i]->precondition_as_hash;
                
                if ($condition->{precondition_type} eq 'package') {
                        Artemis::Builder::build_package($condition->{id}) if $condition->{build};
                } elsif ($condition->{precondition_type} eq 'image') {
#                        Artemis::Image::build_image($condition->{id}) if $condition->{build};
                } elsif ($condition->{precondition_type} eq 'xen') {
                        # check for preconditions recursively
                }
        }
        
        return 0;
        
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

