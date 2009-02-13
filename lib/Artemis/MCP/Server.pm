package Artemis::Net::Server;

use strict;
use warnings;

use Method::Signatures;
use Moose;
use Net::SSH;
use Net::SSH::Expect;
use IO::Socket::INET;
use Sys::Hostname;
use File::Glob ':globally';
use File::Basename;

extends 'Artemis';

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

method conserver_connect($system, $conserver, $conserver_port, $conuser)
{
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
};

=head2 conserver_disconnect

Disconnect the filehandle given as first argument from the conserver.
We first try to quit kindly but if this fails (by what reason ever)
the filehandle is simply closed. Closing a socket can't fail, so the
function always succeeds. Thus no return value is needed.

@param  IO::Socket::INET - file handle connected to the conserver 

@return none

=cut

method conserver_disconnect($sock)
{
        if ($sock) {
                if ($sock->can("connected") and $sock->connected()) {
                        print ($sock "\005c.\n");
                        <$sock>; # ignore return value, since we close the socket anyway
                }
                $sock->close() if $sock->can("close");
        }
};


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

method reboot_system($host)
{
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
                my $cmd = Artemis->cfg->{osrc_rst}." -f $host";
                $self->log->info("trying $cmd");
                `$cmd`;
        }

	return 0;
};

=head2 write_grub_file

This function expects a system name and a state and creates the
appropriate grub config files for this combination. At the moment,
two states are recognised: "nfs" and "disk". The function is not
very generic at the moment. This is hopefully going to change in the
future.

@param string - name of the system 
@param string - state of the test process

Return values still have to be revised

@return success - 0
@return error   - errorstring

=cut

method write_grub_file($system)
{	
        my $artemis_host = Sys::Hostname::hostname();
        my $grub_file    = Artemis->cfg->{paths}{grubpath}."/$system.lst";

	$self->log->debug("writing grub file ($artemis_host, $grub_file)");

	# create the initial grub file for installation of the test system,
	open (GRUBFILE, ">", $grub_file) or return "Can open ".Artemis->cfg->{paths}{grubpath}."/$system.lst for writing: $!";

	my $text="\nserial --unit=0 --speed=115200\nterminal serial\n\n".
          "default 0\ntimeout 2\n\n";
	
        $text .= "title Test System\n".
          "\ttftpserver ".Artemis->cfg->{tftp_server_address}."\n".
            "\tkernel ".Artemis->cfg->{paths}{nfskernel_path}."/bzImage console=ttyS0,115200 noapic acpi=off root=/dev/nfs ro ip=dhcp nfsroot=".Artemis->cfg->{paths}{nfsroot}.
              " artemis_host=$artemis_host";

	print GRUBFILE $text;
	close GRUBFILE;
	return(0);
};

=head2 gettimeout

Determine timeout for tests in testrun with given id.

@param int - test run id

@return success - timeout
@return error   - undef

=cut

method gettimeout($testrun_id)
{
        my $run = model->resultset('Testrun')->search({id=>$testrun_id})->first();
        return 0 if not $run;
        $self->log->debug('Timeout is "'.$run->wait_after_tests.'"');
        return $run->wait_after_tests || 0;
};


=head2 wait_for_testrun

Wait for start and end of a test program. Put start and end time into
database. The function also recognises errors send from the PRC. It returns an
array that can be handed over to tap_report_send. Optional file handle is used
for easier testing.

@param int - testrun id
@param file handle - read from this handle

@return reference to report array

=cut

method wait_for_testrun($testrun_id, $fh)
{
        my ($prc_status, $prc_started, $prc_stopped, $prc_count, $error_occured)=(undef, 0, 0, undef, 0);
        my @report;
        

        # eval block used for timeout
        eval{
                my $timeout = $self->cfg->{times}{boot_timeout};
                
                alarm($timeout);
                $SIG{ALRM}=sub{$error_occured=1;die("timeout for booting test system ($timeout seconds) reached.\n");};

                no warnings 'io';
        MESSAGE:
                while (my $msg=<$fh>) {
                        use warnings;
                        chomp $msg;
                        #        prc_number:0,end-testprogram,prc_count:1
                        my ($number, $status, undef, $error, $count) = $msg =~/prc_number:(\d+),(start|end|error)-testprogram(:(.+))?,prc_count:(\d+)/ 
                          or $self->log->error(qq(Can't parse message "$msg" received from test machine. I'll ignore the message.)) and next MESSAGE;
                        $self->log->debug("status $status in PRC $number, last PRC is $count");
                        
                        if (not defined($prc_count)) {
                                $prc_count = $count;
                        } elsif ($prc_count != $count) {
                                $self->log->error("Got new PRC count for testrun $testrun_id, old value was $prc_count, new value is $count");
                                $prc_count = $count;
                        }


                        if (not defined($prc_status)) {
                                $timeout = $self->gettimeout($testrun_id);
                                alarm($timeout);
                                $SIG{ALRM}=sub{die("timeout for tests ($timeout seconds) reached.\n");};

                                for (my $i=0; $i<$prc_count;$i++) {
                                        $prc_status->[$i] = {start => 0, end => 0};
                                }
                        }
                        
                        if ($status eq 'start') {
                                $prc_status->[$number]->{start} = 1;
                                $prc_started++;
                        } elsif ($status eq 'end') {
                                $prc_status->[$number]->{end} = 1;
                                $prc_stopped++;
                        } elsif ($status eq 'error') {
                                $prc_status->[$number]->{end} = -1;
                                $error_occured=1;
                                $prc_status->[$number]->{error} = $error;
                                $prc_stopped++;
                        } else {
                                $self->log->error("Unknown status $status for PRC $number");
                        }
                        last MESSAGE if $prc_stopped == $count;
                }
        };
        alarm(0);
        if (not $error_occured) {
                @report = ({msg => "All tests finished"});
        }
        else {
                
                # save eval return value, just to be sure
                chomp $@;
                my $got_timeout = $@;
                

                my $offset=0;
                # $prc_status is undefined only if we did not get any message and were
                # kicked out by timeout
                if ($prc_status) {
                        # we got a test in virtualisation host
                        if ($prc_status->[0]->{start} != 0 or $prc_status->[0]->{end} != 0) {
                                if ($prc_status->[0]->{end} == -1) {
                                        push(@report, {error => 1, msg => $prc_status->[0]->{error}});
                                } elsif ($prc_status->[0]->{end} == 1) {
                                        push (@report, {msg => "Test on PRC 0"});
                                } elsif ($@) {
                                        push(@report, {error => 1, msg => "test on PRC 0 started but not finished: $@"});
                                } else {
                                        push(@report, {error => 1, msg => "PRC 0 has unidentifiably end status ".$prc_status->[0]->{end}});
                                        $self->log->warn("PRC 0 has unidentifiably end status ",$prc_status->[0]->{end});
                                }
                                $prc_count--;
                                $offset =1;
                        }
                        shift @$prc_status;
                        

                        for (my $i=0; $i<$prc_count;$i++) {
                                # $prc_status starts with 0, guests starts with 1
                                # offset is used when we removed 
                                my $guest=$i+1+$offset;
                                if ($prc_status->[$i]->{end} == 1) {
                                        push (@report, {msg => "Test on guest $guest"});
                                } elsif ($prc_status->[$i]->{end} == -1) {
                                        push (@report, {error => 1, msg => "guest $guest:".$prc_status->[$i]->{error}});
                                } elsif ($@) {
                                        if ($prc_status->[$i]->{end}) {
                                                if ($prc_status->[$i]->{start}) {
                                                        push(@report, {error => 1, msg => "test on guest $guest started but not finished: $@"});
                                                } else {
                                                        push(@report, {error => 1, msg => "test on guest $guest not started: $@"});
                                                }
                                        }
                                } else {
                                        push(@report, {error => 1, msg => "guest $guest has unidentifiably end status ".$prc_status->[$i]->{end}});
                                        $self->log->warn("guest $guest has unidentifiably end status ",$prc_status->[$i]->{end});
                                }
                        }
                }
                push (@report, {error=> 1, msg => $got_timeout}) if $got_timeout;
        }
        return \@report;
}
;


=head2 upload_files

Upload files written in one stage of the testrun to report framework.

@param int - report id
@param int - testrun id

@return success - 0
@return error   - error string

=cut 

method upload_files($reportid, $testrunid)
{
        my $host = $self->cfg->{report_server};
        my $port = $self->cfg->{report_api_port};
        
        my $path = $self->cfg->{paths}{output_dir};
        $path .= "/$testrunid/";
        my $cwd=`pwd`;
        chdir($path);
        my @files=`find -type f -size +0`;
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
;

=head2 tap_report_send

Send information of current test run status to report framework using TAP
protocol. 

@param int   - test run id
@param array -  report array

@return success - (0, report id)
@return error   - (1, error string)

=cut

method tap_report_send($testrun, $report)
{
        my $tap = $self->tap_report_create($testrun, $report);
        my $reportid;
        $self->log->debug($tap);
        
        if (my $sock = IO::Socket::INET->new(PeerAddr => Artemis->cfg->{report_server},
					     PeerPort => Artemis->cfg->{report_port},
					     Proto    => 'tcp')){
                eval{
                        my $timeout = 100;
                        $SIG{ALRM}=sub{die("timeout for sending tap report ($timeout seconds) reached.");};
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
};
  

=head2 tap_report_create

Create a report string from a report in array form. Since the function only
does data transformation, no error should ever occur.

@param int   - test run id
@param array -  report array

@return report string

=cut

method tap_report_create($testrun, $report)
{
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
};


1;
