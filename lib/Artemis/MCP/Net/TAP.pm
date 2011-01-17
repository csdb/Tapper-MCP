package Artemis::MCP::Net::TAP;

use strict;
use warnings;

use 5.010;

use Moose::Role;

requires 'testrun', 'cfg';

=head2 prc_headerlines

Generate header lines for the TAP report containing the results of the
PRC with the number provided as argument.

=cut

sub prc_headerlines {
        my ($self, $prc_number) = @_;

        my $hostname = $self->associated_hostname;

        my $testrun_id = $self->testrun->id;
        my $suitename =  ($prc_number > 0) ? "Guest-Overview-$prc_number" : "PRC0-Overview";
        
        my $headerlines = [
                           "# Artemis-reportgroup-testrun: $testrun_id",
                           "# Artemis-suite-name: $suitename",
                           "# Artemis-suite-version: $Artemis::MCP::VERSION",
                           "# Artemis-machine-name: $hostname",
                           "# Artemis-section: prc-state-details",
                           "# Artemis-reportgroup-primary: 0",
                          ];
        return $headerlines;
}


=head2 tap_report_away

Actually send the tap report to receiver.

@param string - report to be sent

@return success - (0, report id)
@return error   - (1, error string)

=cut

sub tap_report_away
{
        my ($self, $tap) = @_;
        my $reportid;
        if (my $sock = IO::Socket::INET->new(PeerAddr => $self->cfg->{report_server},
					     PeerPort => $self->cfg->{report_port},
					     Proto    => 'tcp')) {
                eval{
                        my $timeout = 100;
                        local $SIG{ALRM}=sub{die("timeout for sending tap report ($timeout seconds) reached.");};
                        alarm($timeout);
                        ($reportid) = <$sock> =~m/(\d+)$/g;
                        $sock->print($tap);
                };
                alarm(0);
                $self->log->error($@) if $@;
		close $sock;
	} else {
                return(1,"Can not connect to report server: $!");
	}
        return (0,$reportid);

}

=head2 tap_report_send

Send information of current test run status to report framework using TAP
protocol.

@param int   - test run id
@param array -  report array
@param array - header lines

@return success - (0, report id)
@return error   - (1, error string)

=cut

sub tap_report_send
{
        my ($self, $reportlines, $headerlines) = @_;
        my $tap = $self->tap_report_create($reportlines, $headerlines);
        $self->log->debug($tap);
        return $self->tap_report_away($tap);
}

=head2 associated_hostname

Return the name of the host associated to this testrun or 'No hostname
set'.

@return string - hostname

=cut

sub associated_hostname
{
        my ($self) = @_;
        my $hostname;

        eval {
                # parts of this chain may not exists and thus thow an exception
                $hostname = $self->testrun->testrun_scheduling->host->name;
                };
        return ($hostname // 'No hostname set');
}


=head2 suite_headerlines

Generate TAP header lines for the main MCP report.

@param int - testrun id

@return array ref - header lines 

=cut

sub mcp_headerlines {
        my ($self) = @_;

        my $topic = $self->testrun->topic_name() || $self->testrun->shortname();
        $topic =~ s/\s+/-/g;
        my $hostname = $self->associated_hostname();
        my $testrun_id = $self->testrun->id;

        my $headerlines = [
                           "# Artemis-reportgroup-testrun: $testrun_id",
                           "# Artemis-suite-name: Topic-$topic",
                           "# Artemis-suite-version: $Artemis::MCP::VERSION",
                           "# Artemis-machine-name: $hostname",
                           "# Artemis-section: MCP overview",
                           "# Artemis-reportgroup-primary: 1",
                          ];
        return $headerlines;
}

=head2 tap_report_create

Create a report string from a report in array form. Since the function only
does data transformation, no error should ever occur.

@param array ref - report array
@param array ref - header lines

@return report string

=cut

sub tap_report_create
{
        my ($self, $reportlines, $headerlines) = @_;
        my @reportlines  = @$reportlines;
        my $message;
        $message .= "1..".($#reportlines+1)."\n";

        foreach my $line (map { chomp; $_ } @$headerlines) {
                $message .= "$line\n";
        }

        # @reportlines starts with 0, reports start with 1
        for (my $i=1; $i<=$#reportlines+1; $i++) {
                $message .= "not " if $reportlines[$i-1]->{error};
                $message .="ok $i - ";
                $message .= $reportlines[$i-1]->{msg} if $reportlines[$i-1]->{msg};
                $message .="\n";

                $message .= "# ".$reportlines[$i-1]->{comment}."\n"
                  if $reportlines[$i-1]->{comment};
        }
        return ($message);
}


1;
