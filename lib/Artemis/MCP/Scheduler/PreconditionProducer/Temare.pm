use MooseX::Declare;

    
class Artemis::MCP::Scheduler::Producer::Temare extends Artemis::MCP::Scheduler::Producer {
        use YAML::Syck;

=head1 NAME
        
   Artemis::MCP::Scheduler::Producer::Temare - Wraps the existing temare producer

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS


=cut

=head2 features

=cut 
        
        our $temarepath="/home/artemis/temare";
        
        $ENV{PYTHONPATH} .= ":$temarepath/src";
        our $artemispath="/home/artemis/perl510/";
        our $execpath="$artemispath/bin";
        our $grub_precondition=14;
        our $filename="/tmp/temare.yml";


        method produce(Artemis::MCP::Scheduler::TestRequest $request) {
                my $host          =  $request->on_host->name;
                my $yaml   = qx($temarepath/temare subjectprep $host);
                return if $?;
                my $config = Load($yaml);
                my $precond_id;
    
                if ($config) {
                        open (FH,">",$filename) or die "Can't open $filename:$!";
                        print FH $yaml;
                        close FH or die "Can't write $filename:$!";
                        open(FH, "$execpath/artemis-testrun newprecondition --condition_file=$filename|") or die "Can't open pipe:$!";
                        $precond_id = <FH>;
                        chomp $precond_id;
                }

                if (not $precond_id) {
                        system("cp $filename $filename.backup");
                        return;
                }

                my $testrun;
                if ($config->{name} eq "automatically generated KVM test") {
                        $testrun    = qx($execpath/artemis-testrun new --topic=KVM --precondition=$precond_id --host=$host);
                        print "KVM on $host with precondition $precond_id: $testrun";
                } else {
                        $testrun    = qx($execpath/artemis-testrun new --topic=Xen --precondition=$grub_precondition --precondition=$precond_id --host=$host);
                        print "Xen on $host with preconditions $grub_precondition, $precond_id: $testrun";
                }
                my $job = Artemis::MCP::Scheduler::Job->new(host => $request->on_host, testrunid => $testrun);
                return $job;
        }

}
{
        # just for CPAN
        package Artemis::MCP::Scheduler::Producer::Temare;
        our $VERSION = '0.01';
}


=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
