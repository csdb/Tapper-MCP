use MooseX::Declare;

class Artemis::MCP::Scheduler::PreconditionProducer::Kernel
    extends Artemis::MCP::Scheduler::PreconditionProducer {
            use YAML::Syck;

=head1 NAME

Artemis::MCP::Scheduler::PreconditionProducer::Kernel - Produces required preconditions for kernel tests

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS


=cut

=head2 features

=cut 

        sub younger {
                my $st_a = stat($a);
                my $st_b = stat($b);
                return $st_a->mtime() <=> $st_b->mtime();
        }

        method produce(Artemis::MCP::Scheduler::TestRequest $request) {
                my $host          =  $request->on_host-name;
                my @kernelfiles     =  sort younger <$kernel_path/x86_64/*>;
                my $kernelbuild     =  pop @kernelfiles;
        
                my $kernel_version;
                open FH,"tar -tzf $kernelbuild|" or die "Can't look into kernelbuild:$!";
        TARFILES:
                while (my $line = <FH>) {
                        if ($line =~ m/vmlinuz-(.+)$/) {
                                $kernel_version = $1;
                                last TARFILES ;
                        }
                }
                my $id = qx($execpath/artemis-testrun new --macroprecond=/data/bancroft/artemis/live/repository/macropreconditions/kernel/kernel_boot.mpc --hostname=$host -Dkernel_version=$kernel_version -Dkernelpkg=$kernelbuild --owner=mhentsc3 --topic=Kernel);
        
                my $job = Artemis::MCP::Scheduler::Job->new(host => $request->on_host, testrunid => $id);
                return $job;

        }
}
{
        # just for CPAN
        package Artemis::MCP::Scheduler::Producer::Kernel;
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
