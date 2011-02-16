use MooseX::Declare;

## no critic (RequireUseStrict)
class Tapper::MCP::Scheduler::PreconditionProducer::NewestPackage extends Tapper::MCP::Scheduler::PreconditionProducer
{
        use YAML;

        use 5.010;

        use Tapper::Config;
        use File::stat;

        sub younger { stat($a)->mtime() <=> stat($b)->mtime() }

        method produce(Any $job, HashRef $produce) {

                my $source_dir    = $produce->{source_dir};
                my @files = sort younger <$source_dir/*>;
                return {
                        error => 'No files found in $source_dir',
                       } if not @files;
                my $use_file = pop @files;

                my $nfs = Tapper::Config->subconfig->{paths}{prc_nfs_mountdir};
                return {
                        error => "$use_file not available to Installer",
                       } unless $use_file=~/^$nfs/;

                my $retval = [{
                               precondition_type => 'package',
                               filename => $use_file,
                              },];
                return {
                        precondition_yaml => Dump(@$retval),
                       };
        }



}

1;

__END__

=head1 NAME

Tapper::MCP::Scheduler::PreconditionProducer::NewestPackage - Produces a
package precondition that installs the newest package from a given directory.

=head1 SYNOPSIS


=cut

=head2 features

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 OSRC SysInt Team, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

