package Artemis::MCP::Net;

use strict;
use warnings;

use Moose;
use Net::SSH;
use Net::SSH::Expect;
use IO::Socket::INET;
use Sys::Hostname;
use File::Basename;

extends 'Artemis::MCP';

use Artemis::Model 'model';

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
the filehandle is simply closed. Closing a socket can't fail, so the
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


=head2 reboot_system

Reboot the named system. First we try to do it softly, if that doesn't
work, we try a hard reboot. Unfortunately this doesn't give any
feedback. Thus you have to wait for the typical reboot time of the
system in question and if the system doesn't react after this time
assume that the reboot failed. This is not included in this function,
since it would make it to complex.

@param string - name of the system to be rebooted

@return success - 0

=cut

sub reboot_system
{
        my ($self, $host) = @_;
	$self->log->debug("Trying to reboot $host.");
	
	# ssh returns 0 in case of success
        $self->log->info("Try reboot via Net::SSH");  # usually for the nfsrooted system
	if (not Net::SSH::ssh("root\@$host","reboot"))
        {
		$self->log->info("$host rebooted.");
		return 0;
	}
        # Net::SSH::Expect doesn't work correctly atm
# 	else {
#                 $self->log->info("Try reboot via Net::SSH::Expect"); # usually for the installed host/dom0 system
#                 my $ssh = new Net::SSH::Expect( host     => $host,
#                                                 password => 'xyzxyz',
#                                                 user     => 'root',
#                                                 raw_pty  => 1 );


#                 # Try login, with timeout
#                 my $login_output;
#                 eval {
#                         $SIG{ALRM} = sub{ die("timeout in login") };
#                         alarm(10);
#                         $login_output = $ssh->login();
#                 };
#                 alarm(0);

#                 if ($login_output and $login_output !~ /ogin:/)
#                 {
#                         $self->log->info("Logged in. Try exec reboot");
#                         $ssh->exec("stty raw -echo");
#                         $ssh->exec("reboot");
#                         return 0;
#                 }
        else # trigger reset switch
        {
                $self->log->info("Try reboot via reset switch");
                my $cmd = $self->cfg->{osrc_rst}." -f $host";
                $self->log->info("trying $cmd");
                `$cmd`;
        }

	return 0;
}

=head2 write_grub_file

Write a grub file for the system given as parameter. The second parameter is a
port number which is set as 

@param string - name of the system 

@return success - 0
@return error   - error string

=cut

sub write_grub_file
{	
        my ($self, $system) = @_;
        my $artemis_host = Sys::Hostname::hostname();
        my $grub_file    = $self->cfg->{paths}{grubpath}."/$system.lst";

	$self->log->debug("writing grub file ($artemis_host, $grub_file)");

	# create the initial grub file for installation of the test system,
	open (GRUBFILE, ">", $grub_file) or return "Can open ".$self->cfg->{paths}{grubpath}."/$system.lst for writing: $!";

        my $tftp_server = $self->cfg->{tftp_server_address};
        my $kernel = $self->cfg->{paths}{nfskernel_path}."/bzImage";
        my $nfsroot = $self->cfg->{paths}{nfsroot};
	my $text= <<END;
serial --unit=0 --speed=115200
terminal serial

default 0
timeout 2
	
title Test 
     tftpserver $tftp_server
     kernel $kernel console=ttyS0,115200 noapic acpi=off root=/dev/nfs ro ip=dhcp nfsroot=$nfsroot artemis_host=$artemis_host
END
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
        my $cwd=`pwd`;
        chdir($path) or return "Can't change into directory $path:$!";
        my @files=`find -type f`;
        $self->log->debug(@files);
        foreach my $file(@files) {
                chomp $file;
                my $reportfile=$file;
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
        chdir $cwd;
        return 0;
}


=head2 tap_report_send

Send information of current test run status to report framework using TAP
protocol. 

@param int   - test run id
@param array -  report array

@return success - (0, report id)
@return error   - (1, error string)

=cut

sub tap_report_send
{
        my ($self, $testrun, $report) = @_;
        my $tap = $self->tap_report_create($testrun, $report);
        my $reportid;
        $self->log->debug($tap);
        
        if (my $sock = IO::Socket::INET->new(PeerAddr => $self->cfg->{report_server},
					     PeerPort => $self->cfg->{report_port},
					     Proto    => 'tcp')){
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
                return(1,"Can't connect to report server: $!");
	}
        return (0,$reportid);
}
  

=head2 tap_report_create

Create a report string from a report in array form. Since the function only
does data transformation, no error should ever occur.

@param int   - test run id
@param array -  report array

@return report string

=cut

sub tap_report_create
{
        my ($self, $testrun, $report) = @_;
        my @report = @$report;
        my $run = model->resultset('Testrun')->search({id=>$testrun})->first();
        my $hostname = model('HardwareDB')->resultset('Systems')->search({lid => $run->hardwaredb_systems_id})->first->systemname;
        my $message;
        my $topic = $run->topic_name();
        $message .= "1..".($#report+1)."\n";
        $message .= "# Artemis-reportgroup-testrun: $testrun\n";
        $message .= "# Artemis-suite-name: Topic-$topic\n";
        $message .= "# Artemis-suite-version: 1.0\n";
        $message .= "# Artemis-machine-name: $hostname\n";
        $message .= "# Artemis-reportgroup-primary: 1\n";

        # @report starts with 0, reports start with 1
        for (my $i=1; $i<=$#report+1; $i++) {
                # check if == 0, but == fails if $report[$i-1] contains a string
                $message .= "not " if $report[$i-1]->{error};
                $message .="ok $i - ";
                $message .= $report[$i-1]->{msg} if $report[$i-1]->{msg};
                $message .="\n";
        }
        return ($message);
}


1;