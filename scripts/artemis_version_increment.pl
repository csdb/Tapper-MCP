#!/usr/bin/env perl

use strict;
use warnings;

use Perl::Version;

my @output;
open (FH, "<",$ARGV[0]) or die "Can't open $ARGV[0] for reading:$!";
while (my $line = <FH>) {
        if ($line =~ m/(.*\$VERSION.+)(\d\.\d+)(.*)/){
                my $version = Perl::Version->new($2);
                $version->inc_subversion(1);
                push @output, "$1$version$3\n";
        }
        else {
                push @output, $line;
        }
}
close FH;
open (FH,">",$ARGV[0]) or die "Can't open $ARGV[0] for writing:$!";
print FH @output;
close FH;

