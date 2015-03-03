#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

my $USAGE = <<USAGE;

USAGE: $0 <part_size>

* converts the indexes pointing to a single file to indexes pointing to this file partitioned
* indexes to a i-th partition are output on the i-th line in a space-separated sequence
* part_size defined a size of the partition
USAGE

my $part_size;
my $size_file;
GetOptions(
    "size|s=i" => \$part_size,
    "file|f=s" => \$size_file,
);

#if (@ARGV < 1) {
#    print STDERR $USAGE;
#    exit;
#}

if (!$part_size && !$size_file) {
    my @idx = map {chomp $_; $_} (<STDIN>);
    print join ",", @idx;
    print "\n";
    exit;
}

my @accum_sizes;
if (defined $size_file) {
    open my $f, "<", $size_file;
    my @part_sizes = map {chomp $_; $_} <$f>;
    close $f;
    @accum_sizes = ($part_sizes[0]);
    for (my $i = 1; $i < @part_sizes; $i++) {
        push @accum_sizes, $accum_sizes[$i-1] + $part_sizes[$i];
    }
}
my @parts = ();
while (my $num = <STDIN>) {
    chomp $num;
    # calculate the part number and the index within this part
    my $part_no;
    my $part_idx;
    if (@accum_sizes) {
        $part_no = scalar(grep {$num >= $_} @accum_sizes);
        $part_idx = $part_no ? $num - $accum_sizes[$part_no-1] : $num;
    }
    else {
        $part_no = int($num / $part_size);
        $part_idx = $num % $part_size;
    }
    # setting the index for a particular part
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
