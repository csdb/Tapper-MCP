package Artemis::MCP::Net;

use strict;
use warnings;

use 5.010;

use Moose;
use Socket;
use Net::SSH;
use Net::SSH::Expect;
use IO::Socket::INET;
use Sys::Hostname;
use File::Basename;
use YAML;

extends 'Artemis::MCP';

use Artemis::Model qw(model get_hardwaredb_overview);

=head2 conserver_connect

This function opens a connection to the conserver. Conserver, port and user
can be given as arguments, yet are optional.
@param string - system to open a console to
@opt   string - Address or name of the console server
@opt   int    - port number of the console server
@opt   string - username to be used


@returnlist success - (IO::Socket::INET object)
@returnlist error   - (error string)

=cut

sub conserver_connect
{
        my ($self, $system, $conserver, $conserver_port, $conuser) = @_;
        $conserver      ||= $self->cfg->{conserver}{server};
        $conserver_port ||= $self->cfg->{conserver}{port};
        $conuser        ||= $self->cfg->{conserver}{user};

        my $sock = IO::Socket::INET->new(PeerPort => $conserver_port,
                                         PeerAddr => $conserver,
                                         Proto    => 'tcp');

        return ("Can't open connection:$!") unless $sock;
        my $data=<$sock>; return($data) unless $data=~/^ok/;

        print $sock "login $conuser\n";
        $data=<$sock>; return($data) unless $data=~/^ok/;

        print $sock "call $system\n";
        my $port=<$sock>;
        if ($port=~ /@(\w+)/) {
                return $self->conserver_connect ($system,$1,$conserver_port,$conuser);
        } else {
                return($port) unless $port=~/^\d+/;
        }


        print $sock "exit\n";
        $data=<$sock>; return($data) unless $data=~/^goodbye/;
        close $sock;

        $sock = IO::Socket::INET->new(PeerPort => int($port),
                                      PeerAddr => $conserver,
                                      Proto    => 'tcp');
        return ("Can't open connection to $conserver:$!") unless $sock;


        $data=<$sock>;return($data) unless $data=~/^ok/;
        print $sock "login $conuser\n";
        $data=<$sock>;return($data) unless $data=~/^ok/;
        print $sock "call $system\n";
        $data=<$sock>;return($data) unless $data=~/^(\[attached\]|\[spy\])/;

        print ($sock "\005c;\n");  # console needs to be "activated"
        $data=<$sock>;return($data) unless $data=~/^(\[connected\])/;
        return($sock);
}

=head2 conserver_disconnect

Disconnect the filehandle given as first argument from the conserver.
We first try to quit kindly but if this fails (by what reason ever)
the filehandle is simply closed. Closing a socket can not fail, so the
function always succeeds. Thus no return value is needed.

@param  IO::Socket::INET - file handle connected to the conserver

@return none

=cut

sub conserver_disconnect
{
        my ($self, $sock) = @_;
        if ($sock) {
                if ($sock->can("connected") and $sock->connected()) {
                        print ($sock "\005c.\n");
                        <$sock>; # ignore return value, since we close the socket anyway
                }
                $sock->close() if $sock->can("close");
        }
}


=head2 start_simnow

Start a simnow installation on given host. Installer is supposed to
start the simnow controller in turn.

@param string - hostname

@return success - 0
@return error   - error string

=cut

sub start_simnow
{
        my ($self, $hostname) = @_;

        my $simnow_installer = $self->cfg->{files}{simnow_installer};
        my $server = Sys::Hostname::hostname() || $self->cfg->{mcp_host};
        my $retval = Net::SSH::ssh("root\@$hostname",$simnow_installer, "--host=$server");
        return "Can not start simnow installer: $!" if $retval;


        $self->log->info("Simnow installation started on $hostname.");
        return 0;

}


=head2 reboot_system

Reboot the named system. First we try to do it softly, if that does not
work, we try a hard reboot. Unfortunately this does not give any
feedback. Thus you have to wait for the typical reboot time of the
system in question and if the system does not react after this time
assume that the reboot failed. This is not included in this function,
since it would make it to complex.

@param string - name of the system to be rebooted

@return success - 0
@return error   - error string

=cut

sub reboot_system
{
        my ($self, $host) = @_;
	$self->log->debug("Trying to reboot $host.");

	# ssh returns 0 in case of success
        # $self->log->info("Try reboot via Net::SSH");  # usually for the nfsrooted system
	# if (not Net::SSH::ssh("root\@$host","reboot"))
        # {
	# 	$self->log->info("$host rebooted.");
	# 	return 0;
	# }
        # Net::SSH::Expect doesn't work correctly atm
	# else {
        #         $self->log->info("Try reboot via Net::SSH::Expect"); # usually for the installed host/dom0 system
        #         my $ssh = new Net::SSH::Expect( host     => $host,
        #                                         password => 'xyzxyz',
        #                                         user     => 'root',
        #                                         raw_pty  => 1 );


        #         # Try login, with timeout
        #         my $login_output;
        #         eval {
        #                 $SIG{ALRM} = sub{ die("timeout in login") };
        #                 alarm(10);
        #                 $login_output = $ssh->login();
        #         };
        #         alarm(0);

        #         if ($login_output and $login_output !~ /ogin:/)
        #         {
        #                 $self->log->info("Logged in. Try exec reboot");
        #                 $ssh->exec("stty raw -echo");
        #                 $ssh->exec("reboot");
        #                 return 0;
        #         }
        # else trigger reset switch
        {
                $self->log->info("Try reboot via reset switch");
                my $cmd = $self->cfg->{osrc_rst}." -f $host";
                $self->log->info("trying $cmd");
                my ($error, $retval) = $self->log_and_exec($cmd);
                return $retval if $error;
        }

	return 0;
}


=head2 copy_grub_file

Use a given grub file instead of creating it from scratch. The file name can
be given as absolut path or relative to
$self->cfg->{files}->{autoinstall}{grubfiles}.

@param string - name of the system
@param string - source file name
@param int    - artemis_port to put into grub file

@return success - 0
@return error   - error string

=cut


sub copy_grub_file
{
        my ($self, $system, $source, $port) = @_;
        my $artemis_host = Sys::Hostname::hostname();
        my $artemis_ip   = gethostbyname($artemis_host);
        return qq{Can not find IP address of "$artemis_host".} if not $artemis_ip;
        $artemis_ip = inet_ntoa($artemis_ip);

        if (-e $source) {
                open(GRUBFILE, "<", $source) or
                  return "Can open $source for reading: $!";
        }elsif (-e $self->cfg->{path}->{autoinstall}{grubfiles}.$source) {
                open(GRUBFILE, "<", $self->cfg->{path}->{autoinstall}{grubfiles}.$source) or
                  return "Can open ".$self->cfg->{path}->{autoinstall}{grubfiles}.$source." for reading: $!";
        } else {
                return "Can't find autoinstaller for $source";
        }

        my $text;
        while (my $line = <GRUBFILE>) {
                if ($line =~ m/^\s*kernel/) {
                        $line .= " artemis_host=$artemis_host";
                        $line .= " artemis_ip=$artemis_ip";
                        $line .= " artemis_port=$port" if $port;
                }
                $text .= $line;

        }
	return($self->write_grub_file($system, $text));

}


=head2 write_grub_file

Write a grub file for the system given as parameter. An optional second
parameter containing the text to be put into the grub file can be used. If
this parameter is not defined or empty a default value is used.

@param string - name of the system
@param string - text to put into grub file; optional


@return success - 0
@return error   - error string

=cut

sub write_grub_file
{
        my ($self, $system, $text) = @_;
        my $artemis_host = Sys::Hostname::hostname();
        my $artemis_ip   = gethostbyname($artemis_host);
        return qq{Can not find IP address of "$artemis_host".} if not $artemis_ip;
        $artemis_ip = inet_ntoa($artemis_ip);

        my $grub_file    = $self->cfg->{paths}{grubpath}."/$system.lst";

	$self->log->debug("writing grub file ($artemis_host, $grub_file)");

	# create the initial grub file for installation of the test system,
	open (GRUBFILE, ">", $grub_file) or return "Can open ".$self->cfg->{paths}{grubpath}."/$system.lst for writing: $!";

        my $tftp_server = $self->cfg->{tftp_server_address};
        my $kernel = $self->cfg->{paths}{nfskernel_path}."/bzImage";
        my $nfsroot = $self->cfg->{paths}{nfsroot};
	if (not $text) {
                $text = <<END;
serial --unit=0 --speed=115200
terminal serial

default 0
timeout 2

title Test
     tftpserver $tftp_server
     kernel $kernel console=ttyS0,115200 root=/dev/nfs ro ip=dhcp nfsroot=$nfsroot artemis_host=$artemis_host artemis_ip=$artemis_ip
END
        }
	print GRUBFILE $text;
	close GRUBFILE or return "Can't save grub file for $system:$!";
	return(0);
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

                open(FH, "<",$file) or do{$self->log->warn("Can't open $file:$!"); $server->close();next;};
                $server->print($cmdline);
                while (my $line = <FH>) {
                        $server->print($line);
                }
                close(FH);
                $server->close();
        }
        return 0;
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
        my ($self, $testrun, $reportlines, $headerlines) = @_;
        my $tap = $self->tap_report_create($testrun, $reportlines, $headerlines);
        $self->log->debug($tap);
        return $self->tap_report_away($tap);
}

sub suite_headerlines {
        my ($self, $testrun_id) = @_;

        my $run      = model->resultset('Testrun')->search({id=>$testrun_id})->first();
        my $topic = $run->topic_name() || $run->shortname();
        $topic =~ s/\s+/-/g;
        my $host     = model('HardwareDB')->resultset('Systems')->find($run->hardwaredb_systems_id);
        my $hostname = $host->systemname if $host;
        $hostname = $hostname // 'No hostname set';

        my $headerlines = [
                           "# Artemis-reportgroup-testrun: $testrun_id",
                           "# Artemis-suite-name: Topic-$topic",
                           "# Artemis-suite-version: 1.0",
                           "# Artemis-machine-name: $hostname",
                           "# Artemis-section: MCP overview",
                           "# Artemis-reportgroup-primary: 1",
                          ];
        return $headerlines;
}

=head2 tap_report_create

Create a report string from a report in array form. Since the function only
does data transformation, no error should ever occur.

@param int   - test run id
@param array - report array
@param array - header lines

@return report string

=cut

sub tap_report_create
{
        my ($self, $testrun, $reportlines, $headerlines) = @_;
        my @reportlines  = @$reportlines;
        my $message;
        $message .= "1..".($#reportlines+1)."\n";

        foreach my $l (map { chomp; $_ } @$headerlines) {
                $message .= "$l\n";
        }

        # @reportlines starts with 0, reports start with 1
        for (my $i=1; $i<=$#reportlines+1; $i++) {
                # check if == 0, but == fails if $report[$i-1] contains a string
                $message .= "not " if $reportlines[$i-1]->{error};
                $message .="ok $i - ";
                $message .= $reportlines[$i-1]->{msg} if $reportlines[$i-1]->{msg};
                $message .="\n";
        }
        return ($message);
}

=head2 hw_report_send

Send a report containing the test machines hw config as set in the hardware
db.

@param int - testrun id

@return success - 0
@return error   - error string

=cut

sub hw_report_send
{
        my ($self, $testrun_id) = @_;
        my $run       = model->resultset('Testrun')->find($testrun_id);
        my $data = get_hardwaredb_overview($run->hardwaredb_systems_id);
        my $yaml = Dump($data);
        $yaml   .= "...\n";
        $yaml =~ s/^(.*)$/  $1/mg;  # indent
        my $report = sprintf("
TAP Version 13
1..2
# Artemis-Reportgroup-Testrun: %s
# Artemis-Suite-Name: Hardwaredb Overview
# Artemis-Suite-Version: %s
# Artemis-Machine-Name: %s
ok 1 - Getting hardware information
%s
ok 2 - Sending
", $testrun_id, $Artemis::MCP::VERSION, Artemis::Model::get_hostname_for_systems_id($run->hardwaredb_systems_id), $yaml);

        my ($error, $error_string) = $self->tap_report_away($report);
        return $error_string if $error;
        return 0;
}

1;
