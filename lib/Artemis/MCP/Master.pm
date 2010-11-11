use MooseX::Declare;




class Artemis::MCP::Master extends Artemis::MCP
{
        use Devel::Backtrace;
        use File::Path;
        use IO::Select;
        use IO::Handle;
        use Log::Log4perl;
        use POSIX ":sys_wait_h";
        use UNIVERSAL;


        use Artemis::Cmd::Testrun;
        use Artemis::MCP::Child;
        use Artemis::MCP::Net;
        use Artemis::MCP::Scheduler::Controller;
        use Artemis::Model 'model';


=head1 NAME

Artemis::MCP::Master - Wait for new testruns and start a new child when needed.

=head1 SYNOPSIS

 use Artemis::MCP::Master;
 my $mcp = Artemis::MCP::Master->new();
 $mcp->run();

=head1 Attributes


=head2 dead_child

Number of pending dead child processes.

=cut

        has dead_child   => (is => 'rw', default => 0);

=head2 child

Contains all information about all child processes.

=cut

        has child        => (is => 'rw', isa => 'HashRef', default => sub {{}});

=head2 consolefiles

Output files for console logs ordered by file descriptor number.

=cut

        has consolefiles => (is => 'rw', isa => 'ArrayRef', default => sub {[]});


=head2 readset

IO::Select object containing all opened console file handles.

=cut

        has readset      => (is => 'rw');

=head2

Associated Scheduler object.

=cut

        has scheduler    => (is => 'rw', isa => 'Artemis::MCP::Scheduler::Controller');

=head1 FUNCTIONS

=cut

sub BUILD
{
        my $self = shift;
        $self->scheduler(Artemis::MCP::Scheduler::Controller->new());
}


=head2 set_interrupt_handlers

Set interrupt handlers for important signals. No parameters, no return values.

@return success - 0

=cut

        sub set_interrupt_handlers
        {
                my ($self) = @_;
                $SIG{CHLD} = sub {
                        $self->dead_child($self->dead_child + 1);
                };

                # give me a stack trace when ^C
                $SIG{INT} = sub {
                        $SIG{INT}='ignore'; # not reentrant, don't handle signal twice
                        my $backtrace = Devel::Backtrace->new(-start=>2, -format => '%I. %s');

                        print $backtrace;

                        exit -1;
                };
                return 0;
        }

=head2 console_open

Open console connection for given host and appropriate console log output file
for the testrun on host. Returns console on success or an error string for
failure.

@param string - system name
@param int    - testrun id

@retval success - IO::Socket::INET
@retval error   - error string

=cut

        sub console_open
        {
                my ($self, $system, $testrunid) = @_;
                return "Incomplete data given to function console_open" if not $system and defined($testrunid);

                my $path = $self->cfg->{paths}{output_dir}."/$testrunid/";
                File::Path::mkpath($path, {error => \my $retval}) if not -d $path;
                foreach my $diag (@$retval) {
                        my ($file, $message) = each %$diag;
                        return "general error: $message\n" if $file eq '';
                        return "Can't create $file: $message";
                }

                my $net = Artemis::MCP::Net->new();
                my $console;
                eval{
                        local $SIG{ALRM} = sub { die 'Timeout'; };
                        alarm (5);
                        $console = $net->conserver_connect($system);
                };
                alarm 0;
                return "Unable to open console for $system after 5 seconds" if $@;

                return $console if not ref $console eq 'IO::Socket::INET';
                $console->blocking(0);
                $self->readset->add($console);


                $path .= "console";
                open(my $fh,">",$path) or return "Can't open console log file $path for test on host $system:$!";
                $self->consolefiles->[$console->fileno()] = $fh;
                return $console;
        }


=head2 console_close

Close a given console connection.

@param IO::Socket::INET - console connection socket

@retval success - 0
@retval error   - error string

=cut

        sub console_close
        {
                my ($self, $console) = @_;
                return 0 if not ($console and $console->can('fileno'));
                close $self->consolefiles->[$console->fileno()]
                    or return "Can't close console file:$!";
                $self->consolefiles->[$console->fileno()] = undef;
                $self->readset->remove($console);
                my $net = Artemis::MCP::Net->new();
                $net->conserver_disconnect($console);
                alarm 0;
                return 0;
        }

=head2 handle_dead_children

Each test run is handled by a child process. All information needed for
communication with this child process is kept in $self->child. Reset all these
information when the test run is finished and the child process ends.

=cut

        sub handle_dead_children
        {
                my ($self) = @_;
        CHILD: while ($self->dead_child) {
                        $self->log->debug("Number of dead children is ".$self->dead_child);
                        my $dead_pid = waitpid(-1, WNOHANG);  # don't use wait(); qx() sends a SIGCHLD and increases $self->deadchild, but wait() for the return value and thus our wait would block
                        if ($dead_pid <= 0) { # got here because of qx()
                                $self->dead_child($self->dead_child - 1);
                                next CHILD;
                        }
                CHILDREN_CHECK: foreach my $this_child (keys %{$self->child})
                        {
                                if ($self->child->{$this_child}->{pid} == $dead_pid) {
                                        $self->log->debug("$this_child finished");
                                        $self->scheduler->mark_job_as_finished( $self->child->{$this_child}->{job} );
                                        $self->console_close( $self->child->{$this_child}->{console} );
                                        delete $self->child->{$this_child};
                                        $self->dead_child($self->dead_child - 1);
                                        last CHILDREN_CHECK;
                                }
                        }
                }
        }


=head2 consolelogfrom

Read console log from a handle and write it to the appropriate file.

@param file handle - read from this handle

@retval success - 0
@retval error   - error string

=cut

        sub consolelogfrom
        {
                my ($self, $handle) = @_;
                my ($buffer, $readsize);
                my $timeout = 2;
                my $maxread = 1024; # XXX configure
                eval {
                        local $SIG{ALRM}=sub{die 'Timeout'};
                        alarm $timeout;
                        $readsize  = sysread($handle, $buffer, $maxread);
                };
                alarm 0;
                if ($@) {
                        return ("Timeout of $timeout seconds reached while trying to read from console")
                          if $@=~/Timeout/;
                        return ("Error while reading from console handle: $@");
                }

                return "Can't read from console:$!" if not defined $readsize;

                my $file    = $self->consolefiles->[$handle->fileno()];
                return "Can't get console file:$!" if not defined $file;
                $readsize     = syswrite($file, $buffer, $readsize);
                return "Can't write console data to file :$!" if not defined $readsize;
                return 0;
        }


=head2 run_due_tests

Run the tests that are due.

@param TestrunScheduling - job to run
@param boolean - are we in revive mode?

@retval success - 0
@retval error   - error string

=cut

        sub run_due_tests
        {
                my ($self, $job, $revive) = @_;
                $self->log->debug('run_due_test');

                my $system = $job->host->name;
                my $id = $job->testrun->id;

                $self->log->info("start testrun $id on $system");
                # check if this system is already active, just for error handling
                $self->handle_dead_children() if $self->child->{$system};

                $self->scheduler->mark_job_as_running($job) unless $revive;

                my $pid = fork();
                die "fork failed: $!" if (not defined $pid);

                # hello child
                if ($pid == 0) {

                        my $child = Artemis::MCP::Child->new( $id );
                        my $retval;
                        eval {
                                $retval = $child->runtest_handling( $system );
                        };
                        $retval = $@ if $@;

                        if ( ($retval or $child->rerun) and $job->testrun->rerun_on_error) {
                                my $cmd  = Artemis::Cmd::Testrun->new();
                                my $new_id;
                                eval {
                                        $new_id = $cmd->rerun($id, {rerun_on_error => $job->testrun->rerun_on_error - 1});
                                };
                                if ($@) {
                                        $self->log->error($@);
                                } else {
                                        $self->log->debug("Restarted testrun $id with new id $new_id because ".
                                                          "an error occured and rerun_on_error was ".
                                                          $job->testrun->rerun_on_error);
                                }
                        }
                        if ($retval) {
                                $self->log->error("An error occured while trying to run testrun $id on $system: $retval");
                        } else {
                                $self->log->info("Runtest $id finished successfully");
                        }
                        exit 0;
                } else {
                        my $console = $self->console_open($system, $id);

                        if (ref($console) eq 'IO::Socket::INET') {
                                $self->child->{$system}->{console}  = $console;
                        } else {
                                $self->log->info("Can not open console on $system");
                        }

                        $self->child->{$system}->{pid}      = $pid;
                        $self->child->{$system}->{test_run} = $id;
                        $self->child->{$system}->{job}      = $job;
                }
                return 0;

        }


=head2 runloop

Main loop of this module. Checks for new tests and runs them. The looping
itself is put outside of function to allow testing.

=cut

        sub runloop
        {
                my ($self, $lastrun) = @_;
                my $timeout          = $lastrun + $self->cfg->{times}{poll_intervall} - time();

                my @ready;
                # if readset is empty, can_read immediately returns with an empty
                # array; this makes runloop a CPU burn loop
                if ($self->readset->count) {
                        @ready = $self->readset->can_read( $timeout );
                } else {
                        sleep $timeout;
                }
                $self->handle_dead_children() if $self->dead_child;

        HANDLE:
                foreach my $handle (@ready) {
                        if (not $handle->opened()) {
                                $self->readset->remove($handle);
                                next HANDLE;
                        }

                        my $retval = $self->consolelogfrom($handle);
                        if ($retval) {
                                $self->log->error($retval);
                                $self->console_close($handle);
                        }
                }

                if (not @ready) {
                        while ( my @jobs = $self->scheduler->get_next_job() ) {
                                foreach my $job (@jobs) {
                                        # (WORKAROUND) try to avoid to
                                        # children being started close
                                        # to each other and trying to
                                        # reset simulataneously
                                        sleep 2;
                                        $self->run_due_tests($job);
                                }
                        }
                }
        }


=head2 prepare_server

Create communication data structures used in MCP.

@return

=cut

        sub prepare_server
        {
                my ($self) = @_;
                Log::Log4perl->init($self->cfg->{files}{log4perl_cfg});
                # these sets are used by select()
                my $select = IO::Select->new();
                return "Can't create select object:$!" if not $select;
                $self->readset ($select);
                return "Can't create select object:$!" if not $select;

                return 0;
        }

=head2 revive_children

Restart the children that were running before MCP was shut
down/crashed. The function expects no parameters and has no return
values.

=cut

sub revive_children
{
        my ($self) = @_;
        my $jobs = model->resultset('TestrunScheduling')->running;
        foreach my $job ($jobs->all) {
                $self->run_due_tests($job, "revive");
        }
}



=head2 run

Set up all needed data structures then wait for new tests.

=cut

        sub run
        {
                my ($self) = @_;
                $self->set_interrupt_handlers();
                $self->prepare_server();
                $self->revive_children();
                while (1) {
                        my $lastrun = time();
                        $self->runloop($lastrun);
                }

        }
}


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

