#!/usr/bin/env perl

use strict;
use warnings;
use List::Util qw/shuffle/;
use Getopt::Long;

my $lines_count = 1;
my $separator;
my $random_seed;
GetOptions(
    "--lines|l=i" => \$lines_count,
    "--separator|s=s" => \$separator,
    "--random_seed|r=i" => \$random_seed,
);

if (defined $random_seed) {
    srand($random_seed);
}

my @lines;
my $item = "";
my $i = 1;
while (<STDIN>) {
    $item .= $_;
    if ((defined $separator && $_ =~ /$separator/) ||
        (!defined $separator && ($i % $lines_count == 0))) {
        push @lines, $item;
        $item = "";
    }
    $i++;
}
if ($item ne "") {
    push @lines, $item;
}
my @shuffled = shuffle @lines;
print join "", @shuffled;
