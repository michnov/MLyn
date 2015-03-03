#!/usr/bin/env perl

use strict;
use warnings;

my $USAGE = <<USAGE;

USAGE: $0 <part_size>

* converts the indexes pointing to a single file to indexes pointing to this file partitioned
* indexes to a i-th partition are output on the i-th line in a space-separated sequence
* part_size defined a size of the partition
USAGE

#if (@ARGV < 1) {
#    print STDERR $USAGE;
#    exit;
#}
my $part_size = $ARGV[0];

if (!$part_size) {
    my @idx = map {chomp $_; $_} (<STDIN>);
    print join ",", @idx;
    print "\n";
    exit;
}

my @parts = ();
foreach my $num (<STDIN>) {
    chomp $num;
    my $part_no = int($num / $part_size);
    my $part_idx = $num % $part_size;
    if (defined $parts[$part_no]) {
        push @{$parts[$part_no]}, $part_idx;
    }
    else {
        $parts[$part_no] = [$part_idx];
    }
}
foreach my $part (@parts) {
    my $str = defined $part ? (join ",", @$part) : "";
    print "$str\n";
}
