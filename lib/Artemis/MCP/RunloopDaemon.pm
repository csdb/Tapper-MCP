package Artemis::MCP::RunloopDaemon;

use strict;
use warnings;

# TODO: IMHO then the LOG should be made "uninitialization aware", eg.:  "string".($maybe_undef || 'fallback')

use DBI;
use Carp qw(cluck);
use File::Path;
use Log::Log4perl;
use Method::Signatures;

use IO::Handle;
use IO::Select;
use IO::Socket::INET;

use Artemis::Model 'model';
use Artemis::Config;
use Artemis::Scheduler;
use Artemis::MCP::Precondition;
use Moose;

extends 'Artemis';

=head1 NAME

Artemis - Automatic Regression Test Environment and Measurement Instrument System

=head1 VERSION

Version 2.01

=head1 SYNOPSIS

 use Artemis::MCP::RunloopDaemon;

=cut

# ----------------------------- Daemonize stuff ------------------------------

use Moose;
with 'MooseX::Daemonize';

after start => sub {
                    my $self = shift;

                    return unless $self->is_daemon;
                    $self->server_loop;
                   }
;

# ----------------------------- Members ------------------------------

has DEAD_CHILD   => (is  => 'rw', default => 0);

# A test is controlled by a child process. All information for
# communication with these is kept in here.
has child        => (is  => 'rw',
                    isa => 'HashRef',
                    default => sub {{}},
                   );

# output files for console logs ordered by file descriptor number
# this is either a bad hack or brilliant ;-)
has consolefiles => (is  => 'rw',
                    isa => 'ArrayRef',
                    default => sub {[]},
                   );

has server       => (is  => 'rw');
has readset      => (is  => 'rw');
has lastrun      => (is  => 'rw');


# ----------------------------- Methods ------------------------------

=head1 FUNCTIONS

=begin method

Declares a method.

=end method

=head2 set_interrupt_handlers

Some signals (like SIGCHLD) are needed to control run of MCP, others (like
SIGPIPE) are convenient for debug purpose. Set up signal handlers for all
these signals. No parameters or return values are used within this method.

=cut

method set_interrupt_handlers
{
        $SIG{CHLD} = sub {
                          $self->DEAD_CHILD($self->DEAD_CHILD + 1);
                         }
        ;

        $SIG{PIPE} = sub {
                          $self->log->debug("PIPE")
                         }
        ;

        # give me a stack trace when ^C
        $SIG{INT} = sub {
                         cluck();
                         exit -1;
                        }
        ;
};


=begin get_hostname_from_socket

Returns the name of the host that sent a network message by inspecting the
socket.

@param IO::Socket::INET object - connected socket

@return - string - hostname

=end get_hostname_from_socket

=cut

method get_hostname_from_socket ($msg_sock)
{
        my $sockaddr       = $msg_sock->peername();
        my ($port, $iaddr) = sockaddr_in($sockaddr);
        my $fqdn           = gethostbyaddr($iaddr, AF_INET);
        my ($hostname)     = split(/\./, $fqdn); # we need hostnames, no fqdn
        return $hostname;
};

=head2 forward_data_from_remote

Check which sockets have data to read, fetch this data and send it to the
appropriate child process. This child is determined using two different
methods: 
* the host name used for a normal message is the sender of the message
* the host name used for a "command" message is named as the second part of the
  (comma separated value) message 

@return success - 0
@return error   - error string

=cut

method forward_data_from_remote
{
        my $msg_sock = $self->server->accept() or die "can't accept server";
        my $hostname=$self->get_hostname_from_socket($msg_sock);
        
        
        # actually there should be no need to read more than once but better
        # save than sorry (since this is nearly impossible to debug)
        my $message;
        while (defined (my $tmpmsg = <$msg_sock>)) {
                $message.=$tmpmsg;
        }
        close $msg_sock;
        
        # command from admin
        if (my ($tmphost, $tmpmessage) = $message=~m/^command,(\w+),(.+)$/) {
                $hostname = $tmphost;
        }

        if ( not $self->child->{$hostname}) { # we have a test running on this machine
                close $msg_sock;
                return("received $message from $hostname, but no such child exists");
        }
        syswrite $self->child->{$hostname}->{write}, $message;
        return 0;
};


=head2 runtest_handling

Put start time in DB, redirect STDIN and start runtest and wait for completion.

@param int    - test run id
@param string - system name
@param file handle - get remote system messages through this file handle

@return success - 0
@return error   - error string

=cut

method runtest_handling ($id, $system, $fh)
{
        # the test run is controlled fully by this simple function
        my $retval;
        my $installer       = new Artemis::MCP::Installer;
        $retval             = $installer->install($id, $fh);
        
        my $report_id;
        my $error;
        my $net             = new Artemis::MCP::Net;
        if ($retval) {
                ($error, $report_id) = $net->tap_report_send($id, [{error => 1, msg => $retval}]);
                $net->upload_files($report_id, $id);
                return $retval;
        }
        
        $self->log->debug('waiting for test to finish');
        $retval              = $net->wait_for_testrun($id, $fh);
        ($error, $report_id) = $net->tap_report_send($id, $retval);
        return $report_id if $error;

        $retval = $net->upload_files($report_id, $id);
        return $retval if $retval;
        return 0;
        
}
;

=begin run_due_tests

Run the tests that are due.

@param hash - containing test run ids accessible through host names

=end run_due_tests

=cut

method run_due_tests (%due_tests)
{
        $self->log->debug('run_due_test');

SYSTEM:
        foreach my $system (keys %due_tests)
        {
                my $id = $due_tests{$system};
                next SYSTEM if not $id;

                $self->log->debug("test run $id on system $system");
                
                # check if this system is already active
                if ($self->child->{$system})
                {
                        if ($self->child->{$system}->{test_run}==$id)
                        {
                                $self->log->warn("Test run id $id is returned twice.");
                                next SYSTEM;
                        } 
                        else
                        {
                                my $scheduler = Artemis::Scheduler->new();
                                my ($error, $time) = $scheduler->reschedule_testrun($id);
                                $self->log->warn("Got a new test run( id = $id) for $system, but test run ",
                                              $self->child->{$system}->{test_run},
                                              " is still active. Test run $id is rescheduled to ",$time->datetime());
                                next SYSTEM;
                        }
                }
				
		
                $self->log->info("start testing on $system");

                pipe(my $read ,my $write) or $self->log->error("Can't open pipe to talk to child: $!") && next;
                my $console = $self->console_open($system, $id);
                $self->log->error($console) if not ref($console) eq 'IO::Socket::INET';

                my $pid = fork();
                die "fork failed: $!" if (not defined $pid);
		
                # hello child
                if ($pid == 0)
                {
                        close $write;
                        $self->server->close();
                        my $retval = $self->runtest_handling( $id, $system, $read );
                        my $run=model('TestrunDB')->resultset('Testrun')->search({id=>$id})->first();
                        $run->endtime_test_program(model('TestrunDB')->storage->datetime_parser->format_datetime(DateTime->now));
                        $run->update();


                        if ($retval) {
                                $self->log->error("An error occured while trying to run testrun $id on $system: $retval");
                        } else {
                                $self->log->info("Runtest $id finished successfully");
                        }
                        exit 0;
                }
                # hello parent
                else
                {
                        # put the start time into db
                        my $run=model('TestrunDB')->resultset('Testrun')->search({id=>$id})->first();
                        $run->starttime_testrun(model('TestrunDB')->storage->datetime_parser->format_datetime(DateTime->now));
                        $run->update();

                        close $read;
                        $self->child->{$system}->{pid}      = $pid;
                        $self->child->{$system}->{test_run} = $id;
                        $self->child->{$system}->{write}    = $write;
                        $self->child->{$system}->{console}  = $console;

                }
        }
};

=head2 wait_for_communication

Wait for the MCP to receive a message or a timeout to ran out. Returns a
(possibly empty) array of all readable file handles.

@retval array - all readable file handles

=cut

method wait_for_communication($timeout)
{
        $self->log->debug('wait_for_communication');

        # only work every poll intervall
        return $self->readset->can_read( $timeout );
}
;

=head2 console_open

Open console connection for given host and appropriate console log output file
for the testrun on host. Returns console on success or an error string for
failure.

@param string - system name
@param int    - testrun id

@retval success - IO::Socket::INET
@retval error   - error string

=cut

method console_open($system, $testrunid)
{
        my $net = Artemis::MCP::Net->new();
        my $console = $net->conserver_connect($system);
        return $console if not ref $console eq 'IO::Socket::INET';
        $self->readset->add($console);
        my $path = $self->cfg->{paths}{output_dir}."/$testrunid/";
        
        mkpath($path, {error => \my $retval}) if not -d $path;
        foreach my $diag (@$retval) {
                my ($file, $message) = each %$diag;
                return "general error: $message\n" if $file eq '';
                return "Can't create $file: $message";
        }

        $path .= "console";
        open(my $fh,">",$path) or return "Can't open console log file $path for test on host $system:$!";
        $self->consolefiles->[$console->fileno()] = $fh;
        return $console;
};


=head2 console_close

Close a given console connection.

@param IO::Socket::INET - console connection socket

@retval success - 0
@retval error   - error string

=cut

method console_close($console)
{
        close $self->consolefiles->[$console->fileno()] 
          or return "Can't close console file:$!";
        $self->consolefiles->[$console->fileno()] = undef;
        $self->readset->remove($console);
        my $net = Artemis::MCP::Net->new();
        $net->conserver_disconnect($console);
        return 0;
};



=head2 consolelogfrom

Read console log from a handle and write it to the appropriate file.

@param file handle - read from this handle

@retval success - 0
@retval error   - error string

=cut

method consolelogfrom($handle)
{
        my $buffer;
        my $maxread = 1024; # XXX configure
        my $retval  = sysread($handle, $buffer, $maxread);
        return "Can't read from console:$!" if not defined $retval;
        my $file    = $self->consolefiles->[$handle->fileno()];
        $retval     = syswrite($file, $buffer, $retval);
        return "Can't write console data to file :$!" if not defined $retval;
        return 0;
};

=head2 handle_dead_children

Each test run is handled by a child process. All information needed for
communication with this child process is kept in $self->child. Reset all these
information when the test run is finished and the child process ends.

=cut

method handle_dead_children
{

 CHILD: while ($self->DEAD_CHILD) {
                $self->log->debug("Number of dead children is ".$self->DEAD_CHILD);
                my $dead_pid = wait(); # there have to be childs pending, otherwise $self->DEAD_CHILD should be 0
        CHILDREN_CHECK: foreach my $this_child (keys %{$self->child})
                {
                        if ($self->child->{$this_child}->{pid} == $dead_pid) {
                                $self->log->debug("$this_child finished");
                                $self->console_close($self->child->{$this_child}->{console});
                                delete $self->child->{$this_child};
                                $self->DEAD_CHILD($self->DEAD_CHILD - 1);
                                last CHILDREN_CHECK;
                        }
                }
        }
}
;

=head2 control_runtests

Search for due test runs, assign them to precondition handler and handle
communication proxy for all precondition handler processes.

=cut

method control_runtests
{
        my $retval;
        
        $self->log->debug("child is",$self->child);

	
        # check for dead children and remove them from the list
        # SIGCHLD will probably wake up can_read() most often, so here is the best place for this
        $self->log->debug('handle_dead_children');
        $self->handle_dead_children();
        
        my $timeout   = $self->lastrun + $self->cfg->{times}{poll_intervall} - time();
        if ($timeout <= 0) {
                $self->lastrun( time );
                # run_due_tests needs the hostname, so we let get_next_test search it
                my $scheduler = Artemis::Scheduler->new();
                my %due_tests = $scheduler->get_next_testrun();
                $self->run_due_tests(%due_tests);
        }

        my @ready = $self->wait_for_communication($timeout);
        $self->log->debug("ready_set is ".join(" | ",@ready));
        foreach my $handle (@ready) {
                if ($handle == $self->server) {
                        $retval = $self->forward_data_from_remote();
                        $self->log->error($retval) if $retval;
                } else {
                        $retval = $self->consolelogfrom($handle);
                        $self->log->error($retval) if $retval;
                }

        }


}
;

=head2 prepare_server

Create communication data structures used in MCP. 

=cut

method prepare_server
{
        Log::Log4perl->init(Artemis::Config->subconfig->{files}{log4perl_cfg});
        # these sets are used by select()
        $self->readset (new IO::Select);
        # through this socket we get status messages from the test systems
        $self->server (IO::Socket::INET->new(Listen    => 5,
                                             LocalPort => $self->cfg->{mcp_port},
                                             Proto     => 'tcp'
                                            )
                       or die "Can't open server for test system status updates:$!");
        $self->readset->add( $self->server );
};

=head2 server_loop

Main server function. This is a wrapper around the work of MCP and runs
forver.

=cut

# cperl-mode indenting bug after "method s.*"
method server_loop
{
        $self->set_interrupt_handlers();
        $self->prepare_server();

        while (1) {
                $self->control_runtests();
        }
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

