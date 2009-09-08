package Artemis::MCP::Scheduler::Model;

use warnings;
use strict;
use 5.010;

use Class::C3;
use MRO::Compat;

use Memoize;
use Artemis::Config;
use Artemis::Model;
use parent 'Exporter';

our @EXPORT_OK = qw(model);

memoize('model');
sub model
{
        my ($schema_basename) = @_;

        my $model = Artemis::Model::model(@_);
        return $model;
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
