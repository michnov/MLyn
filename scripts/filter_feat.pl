#!/usr/bin/env perl

use strict;
use warnings;

use lib "$ENV{TMT_ROOT}/personal/mnovak/ml_framework/lib";
use Utils;
use Getopt::Long;

my $in = '';
my $out = '';

GetOptions (
    "in=s" => \$in,
    "out=s" => \$out,
);

my %in_hash = map {$_ => 1} split /,/, $in;
my %out_hash = map {$_ => 1} split /,/, $out;

my $print;
my %hash;
if (keys %in_hash > 0) {
    $print = 0;
    %hash = %in_hash;
} elsif (keys %out_hash > 0) {
    $print = 1;
    %hash = %out_hash;
} else {
    print $_ while (<STDIN>);
}


while (<STDIN>) {
    my ($feats, $class) = Utils::parse_line($_);

    my @filt_feats = grep { $print xor $hash{(split /=/, $_)[0]} } @$feats;
    print "$class\t" . (join " ", @filt_feats) . "\n";
}
