use MooseX::Declare;

## no critic (RequireUseStrict)
class Artemis::MCP::Scheduler::PreconditionProducer::Kernel extends Artemis::MCP::Scheduler::PreconditionProducer
{
        use YAML;

        use 5.010;

        use aliased 'Artemis::Config';
        use File::stat;

        sub younger { stat($a)->mtime() <=> stat($b)->mtime() }

        # try to get the kernel version by reading the files in the packet
        # this approach works since that way the kernel_version required by gen_initrd
        # even if other approaches would report different version strings
        method get_version(Str $kernelbuild)
        {
                my @files;
                if ($kernelbuild =~ m/gz$/) {
                        @files = qx(tar -tzf $kernelbuild);
                } elsif ($kernelbuild =~ m/bz2$/) {
                        @files = qx(tar -tjf $kernelbuild);
                } else {
                        return {error => 'Can not detect type of file $kernelbuild. Supported types are tar.gz and tar.bz2'};
                }
                chomp @files;
                foreach my $file (@files) {
                        if ($file =~m|boot/vmlinuz-(.+)$|) {
                                return {version => $1};
                        }
                }
        }

        method produce(Any $job, HashRef $produce) {

                my $pkg_dir     = Config->subconfig->{paths}{package_dir};
                
                # project may be x86_64, stable/x86_64, ...
                my $project        = $produce->{arch} // 'x86_64';
                my $kernel_path = $pkg_dir."/kernel";
                $project           = "stable/$project" if $produce->{stable};


                my $version     = '*';
                $version       .= "$produce->{version}*" if $produce->{version};
                my @kernelfiles = sort younger <$kernel_path/$project/$version>;
                return {
                        error => 'No kernel files found',
                       } if not @kernelfiles;
                my $kernelbuild = pop @kernelfiles;
                my $retval  = $self->get_version($kernelbuild);
                if ($retval->{error}) {
                        return $retval;
                }
                my $kernel_version = $retval->{version};
                my ($kernel_major_version) = $kernel_version =~ m/(2\.\d{1,2}\.\d{1,2})/;
                ($kernelbuild)  = $kernelbuild =~ m|$pkg_dir/(kernel/$project/.+)$|;


                $retval = [
                           {
                            precondition_type => 'package',
                            filename => $kernelbuild,
                           },
                           {
                            precondition_type => 'exec',
                            filename =>  '/bin/gen_initrd.sh',
                            options => [ $kernel_version ],
                           }
                          ];

                return {
                        topic => $produce->{topic} // "kernel-$kernel_major_version-reboot",
                        precondition_yaml => Dump(@$retval),
                       };
        }



}

1;

__END__

=head1 NAME

Artemis::MCP::Scheduler::PreconditionProducer::Kernel - Produces required preconditions for kernel tests

=head1 SYNOPSIS


=cut

=head2 features

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

