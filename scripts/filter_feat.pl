#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::ML::TabSpace::Util;
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
    my ($feats, $class) = Treex::Tool::ML::TabSpace::Util::parse_line($_, {split_key_val => 1});
    print "\n" if (!defined $feats);

    my @filt_feats = grep { $print xor $hash{$_->[0]} } @$feats;
    next if (!@filt_feats);
    my $str = Treex::Tool::ML::TabSpace::Util::format_line(\@filt_feats, $class);
    print $str;
}
