use MooseX::Declare;

use 5.010;

class Artemis::MCP::Scheduler::PrioQueue
{
        use Artemis::Exception::Param;

        use Artemis::Model 'model';
        use aliased 'Artemis::Schema::TestrunDB::Result::TestrunScheduling';

        method _max_seq {
                my $job_with_max_seq = model('TestrunDB')->resultset('TestrunScheduling')->search
                    (
                     { prioqueue_seq => { '>', 0 } },
                     {
                      select => [ { max => 'prioqueue_seq' } ],
                      as     => [ 'max_seq' ], }
                    )->first;
                return $job_with_max_seq->get_column('max_seq')
                  if $job_with_max_seq and defined $job_with_max_seq->get_column('max_seq');
                return 0;
        }

        method add($job, $is_subtestrun?)
        {
                my $max_seq = $self->_max_seq;
                $job->prioqueue_seq($max_seq + 1);
                $job->update;
        }

        method get_testrequests # get_jobs
        {
                no strict 'refs';
                my $testrequests_rs = model('TestrunDB')->resultset('TestrunScheduling')->search
                    ({
                      prioqueue_seq => { '>', 0 }
                     },
                     {
                      order_by => 'prioqueue_seq'
                     }
                    );
                return $testrequests_rs;
        }

        method get_first_fitting($free_hosts) {
                my $jobs = $self->get_testrequests;
                while (my $job = $jobs->next()) {
                        if (my $host = $job->fits($free_hosts)) {
                                $job->host_id ($host->id);

                                if ($job->testrun->scenario_element) {
                                        $job->testrun->scenario_element->is_fitted(1);
                                        $job->testrun->scenario_element->update();
                                }

                                return $job;
                        }
                }
                return;
        }
}

{
        # help the CPAN indexer
        package Artemis::MCP::Scheduler::Queue;
        our $VERSION = '0.01';
}

__END__

=head1 NAME

Artemis::MCP::Scheduler::Queue - Object for test queue abstraction

=head1 SYNOPSIS

=head1 FUNCTIONS

=head2 get_test_request

Get a testrequest for one of the free hosts provided as parameter.

@param array ref - list of hostnames

@return success               - Job
@return no fitting tr found   - 0

=head2 produce


Call the producer method associated with this object.

@param string - hostname

@return success - test run id
@return error   - exception



=head1 AUTHOR

Maik Hentsche, C<< <maik.hentsche at amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Maik Hentsche, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

# Idea: provide functions that map to feature has

1;

