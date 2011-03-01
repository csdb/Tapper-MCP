use MooseX::Declare;

## no critic (RequireUseStrict)
class Tapper::MCP::Scheduler::PreconditionProducer {
        #
}

{
        # just for CPAN
        package Tapper::MCP::Scheduler::PreconditionProducer;
}

1; # End of WFQ

__END__

=head1 NAME

Tapper::MCP::Scheduler::PreconditionProducer - Generate Testruns

=head1 SYNOPSIS

Implements a test for weighted fair queueing scheduling algorithm.


=head1 FUNCTIONS

=head2 produce

Create files needed for a testrun and put it into db.

@param string - hostname

@return success - testrun id

=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>


=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

