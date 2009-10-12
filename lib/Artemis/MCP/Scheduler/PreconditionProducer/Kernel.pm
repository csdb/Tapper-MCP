use MooseX::Declare;

class Artemis::MCP::Scheduler::PreconditionProducer::Kernel extends Artemis::MCP::Scheduler::PreconditionProducer
{
        use YAML;

        use 5.010;

        use aliased 'Artemis::Config';
        use File::stat;

        sub younger { stat($a)->mtime() <=> stat($b)->mtime() }

        method produce(Any $job, HashRef $produce) {

                my $pkg_dir     = Config->subconfig->{package_dir};
                my $arch        = $produce->{arch} // 'x86_64';
                my $kernel_path = $pkg_dir."/kernel";
                my @kernelfiles = sort younger <$kernel_path/$arch/*>;
                return {
                        error => 'No kernel files found',
                       } if not @kernelfiles;
                my $kernelbuild = pop @kernelfiles;
                ($kernelbuild)  = $kernelbuild =~ m|$pkg_dir/(kernel/$arch/.+)$|;

                my $retval = {
                              precondition_type => 'package', 
                              filename => $kernelbuild,
                             };


                return {
                        precondition_yaml => Dump($retval),
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

