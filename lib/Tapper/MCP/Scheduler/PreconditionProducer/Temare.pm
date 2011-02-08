use MooseX::Declare;

## no critic (RequireUseStrict)
class Tapper::MCP::Scheduler::PreconditionProducer::Temare extends Tapper::MCP::Scheduler::PreconditionProducer {
        use File::Temp 'tempfile';
        use YAML       'LoadFile';
        use Tapper::Config;

        method produce(Any $job, HashRef $produce)
        {
                my ($fh, $file) = tempfile( UNLINK => 1 );

                use Data::Dumper;
                my $temare_path=Tapper::Config->subconfig->{paths}{temare_path};
                
                $ENV{PYTHONPATH}="$temare_path/src";
                my $subject = $produce->{subject};
                my $bitness = $produce->{bitness};
                my $host =  $job->host->name;
                $ENV{TAPPER_TEMARE} = $file;
                my $cmd="$temare_path/temare subjectprep $host $subject $bitness";
                my $yaml = qx($cmd);
                return {error => $yaml} if $?;
                
                my $config = LoadFile($file);
                close $fh;
                unlink $file if -e $file;
                my $topic = $config->{subject} || 'Misc';
                return {
                        topic => $topic,
                        precondition_yaml => $yaml
                       };
        }

}

{
        # help the CPAN indexer
        package Tapper::MCP::Scheduler::PreconditionProducer::Temare;
        our $VERSION = '0.01';
}

1;

__END__


=head1 NAME

Tapper::MCP::Scheduler::PreconditionProducer::Temare - Wraps the existing temare producer

=head1 SYNOPSIS


=cut

=head2 features

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
