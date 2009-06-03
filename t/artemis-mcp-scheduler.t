#! /usr/bin/env perl

use strict;
use warnings;

# get rid of warnings
use Class::C3;
use MRO::Compat;

use Test::More tests => 1;

is(1,1, 'Dummy test');

__END__
method get_job {
        my $job = $self->scheduler->get_job;
        sleep $grace_period if not $job;
}

method execute_job {
        return unless $job;
}

method execute_next_job {
        $self->execute_job ($self->get_job);
}

$self->execute_next_job while 1;
