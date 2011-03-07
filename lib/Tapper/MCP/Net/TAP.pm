package Tapper::MCP::Net::TAP;

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
                           "# Tapper-reportgroup-testrun: $testrun_id",
                           "# Tapper-suite-name: $suitename",
                           "# Tapper-suite-version: $Tapper::MCP::VERSION",
                           "# Tapper-machine-name: $hostname",
                           "# Tapper-section: prc-state-details",
                           "# Tapper-reportgroup-primary: 0",
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
                           "# Tapper-reportgroup-testrun: $testrun_id",
                           "# Tapper-suite-name: Topic-$topic",
                           "# Tapper-suite-version: $Tapper::MCP::VERSION",
                           "# Tapper-machine-name: $hostname",
                           "# Tapper-section: MCP overview",
                           "# Tapper-reportgroup-primary: 1",
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


=head2 upload_files

Upload files written in one stage of the testrun to report framework.

@param int - report id
@param int - testrun id

@return success - 0
@return error   - error string

=cut

sub upload_files
{
        my ($self, $reportid, $testrunid) = @_;
        my $host = $self->cfg->{report_server};
        my $port = $self->cfg->{report_api_port};

        my $path = $self->cfg->{paths}{output_dir};
        $path .= "/$testrunid/";
        my @files=`find $path -type f`;
        $self->log->debug(@files);
        foreach my $file(@files) {
                chomp $file;
                my $reportfile=$file;
                $reportfile =~ s|^$path||;
                $reportfile =~ s|^./||;
                $reportfile =~ s|[^A-Za-z0-9_-]|_|g;
                my $cmdline =  "#! upload $reportid ";
                $cmdline   .=  $reportfile;
                $cmdline   .=  " plain\n";

                my $server = IO::Socket::INET->new(PeerAddr => $host,
                                                   PeerPort => $port);
                return "Cannot open remote receiver $host:$port" if not $server;

                open(my $FH, "<",$file) or do{$self->log->warn("Can't open $file:$!"); $server->close();next;};
                $server->print($cmdline);
                while (my $line = <$FH>) {
                        $server->print($line);
                }
                close($FH);
                $server->close();
        }
        return 0;
}


1;
