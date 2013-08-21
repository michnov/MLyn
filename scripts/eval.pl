#!/usr/bin/env perl

use warnings;
use strict;

#binmode STDIN, ":utf8";

my $total = 0;
my $eq = 0;

while (<STDIN>) {
    chomp $_;
    my ($true, $pred) = split /\s/, $_;

    $total++;
    $eq += ($true eq $pred ? 1 : 0);
}

printf "%.2f (%d/%d)\n", ($eq / $total) * 100, $eq, $total;
