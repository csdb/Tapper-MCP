package Artemis::MCP::Scheduler::Model;

use warnings;
use strict;
use 5.010;

use Class::C3;
use MRO::Compat;

use Memoize;
use Artemis::Config;
use parent 'Exporter';

our @EXPORT_OK = qw(model);

memoize('model');
sub model
{
        my ($schema_basename) = @_;

        $schema_basename ||= 'TestrunDB';

        my $schema_class = "Artemis::MCP::Scheduler::Schema::$schema_basename";

        # lazy load class
        eval "use $schema_class";
        if ($@) {
                print STDERR $@;
                return undef;
        }
        return $schema_class->connect(Artemis::Config->subconfig->{database}{$schema_basename}{dsn},
                                      Artemis::Config->subconfig->{database}{$schema_basename}{username},
                                      Artemis::Config->subconfig->{database}{$schema_basename}{password});
}


=head1 NAME

Artemis::MCP::Scheduler::Model - Get a connected Artemis Schema, using the MCP variants

=head1 SYNOPSIS

    use Artemis::MCP::Scheduler::Model 'model';
    # ...

=head1 EXPORT

=head2 model

Returns a connected schema.

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: restrictive


=cut

1; # End of Artemis::Model
