#!/usr/bin/env perl

# a script to compare results of two models (as triples) 
# to get a statistics how many times the first beats the
# second and vice versa

use strict;
use warnings;
use EvalTriples;

open my $file1, $ARGV[0]; 
open my $file2, $ARGV[1]; 

while (my $line1 = <$file1>) {
    my $line2 = <$file2>;

    my @counts1 = split / /, $line1;
    my @counts2 = split / /, $line2;
    
    my $acc1 = EvalTriples::acc_lenient(@counts1);
    my $acc2 = EvalTriples::acc_lenient(@counts2);

    print "$acc1 $acc2\n";
}
