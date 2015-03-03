#!/usr/bin/env perl

use strict;
use warnings;

use Math::Random;

my $USAGE = <<USAGE;

USAGE: $0 <seed_size> <seq_length> [<seed_init>]

* prints out the newline-separated sequence of random ints thrown from the interval 0 .. seed_size-1 without replacement
* the length of the sequence must be specified in seq_length
* by setting the seed_init, one can change the initialization of the random seed (default=0)
USAGE

my $size = $ARGV[0];
my $count = $ARGV[1];
my $i = $ARGV[2] // 0;

if (@ARGV < 2 || $count > $size) {
    print STDERR $USAGE;
    exit;
}

srand(1986+$i);

my %set = ();
while (keys %set < $count) {
    my $key = int(rand($size));
    if (!$set{$key}) {
        $set{$key} = 1;
    }
}

print join "\n", sort {$a <=> $b} keys %set;
print "\n";
