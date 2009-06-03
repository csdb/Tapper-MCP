package Artemis::MCP::Master;

use strict;
use warnings;

use Devel::Backtrace;
use File::Path;
use IO::Select;
use Log::Log4perl;
use Moose;

use Artemis::MCP::Child;
use Artemis::MCP::Net;
use Artemis::MCP::Scheduler;
use Artemis::Model 'model';

extends 'Artemis::MCP';


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

has dead_child   => (is      => 'rw',
                     default => 0);

=head2 child

Contains all information about all child processes.

=cut

has child        => (is      => 'rw',
                     isa     => 'HashRef',
                     default => sub {{}},
                    );

=head2 consolefiles

Output files for console logs ordered by file descriptor number.

=cut 
  
has consolefiles => (is      => 'rw',
                     isa     => 'ArrayRef',
                     default => sub {[]},
                    );


=head2 readset

IO::Select object containing all opened console file handles.

=cut
  
has readset      => (is      => 'rw');



=head1 FUNCTIONS

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

        my $net = Artemis::MCP::Net->new();
        my $console = $net->conserver_connect($system);
        return $console if not ref $console eq 'IO::Socket::INET';
        $self->readset->add($console);
        my $path = $self->cfg->{paths}{output_dir}."/$testrunid/";
        
        File::Path::mkpath($path, {error => \my $retval}) if not -d $path;
        foreach my $diag (@$retval) {
                my ($file, $message) = each %$diag;
                return "general error: $message\n" if $file eq '';
                return "Can't create $file: $message";
        }

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
        close $self->consolefiles->[$console->fileno()] 
          or return "Can't close console file:$!";
        $self->consolefiles->[$console->fileno()] = undef;
        $self->readset->remove($console);
        my $net = Artemis::MCP::Net->new();
        $net->conserver_disconnect($console);
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
                my $dead_pid = wait(); # there have to be childs pending, otherwise $self->DEAD_CHILD should be 0
        CHILDREN_CHECK: foreach my $this_child (keys %{$self->child})
                {
                        if ($self->child->{$this_child}->{pid} == $dead_pid) {
                                $self->log->debug("$this_child finished");
                                $self->console_close($self->child->{$this_child}->{console});
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
        my $buffer;
        my $maxread = 1024; # XXX configure
        my $retval  = sysread($handle, $buffer, $maxread);
        return "Can't read from console:$!" if not defined $retval;
        my $file    = $self->consolefiles->[$handle->fileno()];
        return "Can't get console file:$!" if not defined $file;
        $retval     = syswrite($file, $buffer, $retval);
        return "Can't write console data to file :$!" if not defined $retval;
        return 0;
}


=head2 run_due_tests

Run the tests that are due.

@param hash - containing test run ids accessible through host names

@retval success - 0
@retval error   - error string

=cut

sub run_due_tests
{
         my ($self, $due_tests) = @_;
        $self->log->debug('run_due_test');

SYSTEM:
        foreach my $system (keys %$due_tests)
        {
                my $id = $due_tests->{$system};
                next SYSTEM if not $id;

                $self->log->debug("test run $id on system $system");
                
                # check if this system is already active
                if ($self->child->{$system})
                {
                        if ($self->child->{$system}->{test_run}==$id)
                        {
                                # Occurs in the rare case that child updates
                                # the test run in the db(inside forked child) slower
                                # than parent rereads the schedule 
                                $self->log->warn("Test run id $id is returned twice.");
                                next SYSTEM;
                        } 
                        else
                        {
                                my $scheduler = Artemis::MCP::Scheduler->new();
                                my ($error, $time) = $scheduler->reschedule_testrun($id);
                                $self->log->warn("Got a new test run( id = $id) for $system, but test run ",
                                              $self->child->{$system}->{test_run},
                                              " is still active. Test run $id is rescheduled to ",$time->datetime());
                                next SYSTEM;
                        }
                }
				
		
                $self->log->info("start testing on $system");

                my $pid = fork();
                die "fork failed: $!" if (not defined $pid);
		
                # hello child
                if ($pid == 0)
                {
                 
                        # put the start time into db
                        my $run=model('TestrunDB')->resultset('Testrun')->search({id=>$id})->first();
                        $run->starttime_testrun(model('TestrunDB')->storage->datetime_parser->format_datetime(DateTime->now));
                        $run->update();
                        my $child = Artemis::MCP::Child->new($id);
                        my $retval = $child->runtest_handling( $system );
                        $run->endtime_test_program(model('TestrunDB')->storage->datetime_parser->format_datetime(DateTime->now));
                        $run->update();

                        if ($retval) {
                                $self->log->error("An error occured while trying to run testrun $id on $system: $retval");
                        } else {
                                $self->log->info("Runtest $id finished successfully");
                        }
                        exit 0;
                }
                else
                {
                        my $console = $self->console_open($system, $id);
                        $self->log->error($console) if not ref($console) eq 'IO::Socket::INET';

                        $self->child->{$system}->{pid}      = $pid;
                        $self->child->{$system}->{test_run} = $id;
                        $self->child->{$system}->{console}  = $console;
                }
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

        foreach my $handle (@ready) {
                my $retval = $self->consolelogfrom($handle);
                $self->log->error($retval) if $retval;
        }

        if (not @ready) {
                # run_due_tests needs the hostname, so we let get_next_test search it
                my $scheduler = Artemis::MCP::Scheduler->new();
                my %due_tests = $scheduler->get_next_testrun();
                $self->run_due_tests(\%due_tests);
        }
}


=head2 prepare_server

Create communication data structures used in MCP. 

=cut

sub prepare_server
{
        my ($self) = @_;
        Log::Log4perl->init($self->cfg->{files}{log4perl_cfg});
        # these sets are used by select()
        my $select = IO::Select->new();
        return "Can't create select object:$!" if not $select;
        $self->readset ($select);
        return 0;
}


=head2 run

Set up all needed data structures then wait for new tests.

=cut

sub start
{
        my ($self) = @_;
        $self->set_interrupt_handlers();
        $self->prepare_server();
        while (1) {
                my $lastrun = time();
                $self->runloop($lastrun);
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

