package Artemis::MCP::Scheduler;

use 5.010;
use strict;
use warnings;

use Moose;
use Artemis::Model 'model';
use Data::Dumper;

extends 'Artemis::MCP';

=head1 NAME

Artemis::MCP::Scheduler - Arrange upcoming test runs in appropriate order

=head1 SYNOPSIS

 use Artemis::MCP::Scheduler;
 my $scheduler = Artemis::MCP::Scheduler;
 $scheduler->get_next_testrun;

=head1 FUNCTIONS

=cut

=head2

Get the hostname associated to the given testrun, get the currently active id
associated with this hostname in the hardware database, set this id as used
system for the given testrun and return the found hostname.

@param DBIx::Class object - found testrun result

@return success - hostname

=cut

sub get_hostname_from_refreshed_testrun
{
        my ($self, $testrun) = @_;
        if (not $testrun->hardwaredb_systems_id)
        {
                #say STDERR "testrun: ", $testrun->to_string;
                #say STDERR "No hardwaredb_systems_id available for testrun ", $testrun->id;
                return undef;
        }

        my $system = model('HardwareDB')->resultset('Systems')->search({ lid => $testrun->hardwaredb_systems_id })->first;
        my $hostname = $system->systemname;
        my $lid = model('HardwareDB')->resultset('Systems')->search({systemname => $hostname, active => 1})->first->lid;
        $testrun->hardwaredb_systems_id($lid);
        $testrun->update();
        return $hostname;
}

=head2 get_next_testrun

Get next test runs to handle.

@returnhash array containing ids of all due testruns

=cut 

sub get_next_testrun
{
        my ($self, $free_hosts) = @_;
        my %ids;
        my $testruns=model('TestrunDB')->resultset('Testrun')->due_testruns();
        foreach my $testrun($testruns->all) {
                my $hostname = $self->get_hostname_from_refreshed_testrun($testrun);
                $ids{$hostname}=$testrun->id if $hostname and not $ids{$hostname};
                #delete $free_hosts->{$hostname} if $free_hosts->{$hostname};
        }

        # foreach my $hostname (keys %$free_hosts) {
        #         $ids{$hostname} = $self->schedule($hostname);
        # }
        say STDERR "Next testruns: ", Dumper(\%ids);
        return %ids;
}

=head2 reschedule_testrun

Set a new earliest starttime for a testrun. The current implementation does
this without considering other testruns only by increasing this earlistest
starttime by a configurabe delay. It returns a list containing zero and the
new time as a datetime object. If an error occured, a list containing 1 and an
error string is returned.

@param int - testrun id

@returnlist success - (0, datetime)
@returnlist error   - (1, error string)

=cut

sub reschedule_testrun
{
        my ($self, $testrun) = @_;
        my $run  = model->resultset('Testrun')->search({id=>$testrun})->first();
        my $time = DateTime->now;
        $time->add(seconds => $self->cfg->{times}{reschedule_time});
        $run->starttime_earliest(model('TestrunDB')->storage->datetime_parser->format_datetime($time));
        $run->update();
        return (0,$time);
}


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

=cut

1;
