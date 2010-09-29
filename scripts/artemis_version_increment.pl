#!/usr/bin/env perl

use strict;
use warnings;

use Perl::Version;

my @output;
open (my $fh, "<",$ARGV[0]) or die "Can't open $ARGV[0] for reading:$!";
while (my $line = <$fh>) {
        if ($line =~ m/(.*\$VERSION.+)(\d\.\d+)(.*)/){
                my $version = Perl::Version->new($2);
                $version->inc_subversion(1);
                push @output, "$1$version$3\n";
        }
        else {
                push @output, $line;
        }
}
close $fh;
open ($fh,">",$ARGV[0]) or die "Can't open $ARGV[0] for writing:$!";
print $fh @output;
close $fh;

