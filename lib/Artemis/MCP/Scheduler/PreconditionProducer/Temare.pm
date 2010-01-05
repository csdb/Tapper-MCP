use MooseX::Declare;

class Artemis::MCP::Scheduler::PreconditionProducer::Temare extends Artemis::MCP::Scheduler::PreconditionProducer {
        use File::Temp 'tempfile';
        use YAML       'LoadFile';
        use Artemis::Config;

        method produce(Any $job, HashRef $produce)
        {
                my ($fh, $file) = tempfile( UNLINK => 1 );

                use Data::Dumper;
                my $temare_path=Artemis::Config->subconfig->{paths}{temare_path};
                
                $ENV{PYTHONPATH}="$temare_path/src";
                my $subject = $produce->{subject};
                my $bitness = $produce->{bitness};
                my $host =  $job->host->name;
                $ENV{ARTEMIS_TEMARE} = $file;
                my $cmd="$temare_path/temare subjectprep $host $subject $bitness";
                my $yaml = qx($cmd);
                return {error => $yaml} if $?;
                
                my $config = LoadFile($file);
                my $topic = $config->{subject} || 'Misc';
                return {
                        topic => $topic,
                        precondition_yaml => $yaml
                       };
        }

}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::Producer::Temare;
        our $VERSION = '0.01';
}

1;

__END__


=head1 NAME

Artemis::MCP::Scheduler::PreconditionProducer::Temare - Wraps the existing temare producer

=head1 SYNOPSIS


=cut

=head2 features

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
