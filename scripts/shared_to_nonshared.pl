#!/usr/bin/env perl

use warnings;
use strict;

while (my $line = <>) {
    chomp $line;
    my ($shared_first, @shared_rest) = split /\t/, $line;
    my @shared_feats;
    if ($shared_first =~ /^shared/) {
        (my $shared_label, @shared_feats) = split /\|/, $shared_first;
    }

    $line = <>;
    chomp $line;
    while (defined $line && $line !~ /^\s*$/) {
        my ($vw_example, @rest) = split /\t/, $line;
        my $instance = join " |", ($vw_example, @shared_feats);
        $instance = join "\t", ($instance, @shared_rest);
        print $instance."\n";
        $line = <>;
        chomp $line;
    }

    print "\n";
}
