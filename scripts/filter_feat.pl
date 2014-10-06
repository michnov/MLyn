#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::ML::VowpalWabbit::Util;
use Getopt::Long;
use Data::Dumper;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

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

while ( my ($feats, @rest) = Treex::Tool::ML::VowpalWabbit::Util::parse_singleline(*STDIN, {parse_feats => 'pair'}) ) {
    if (!@$feats) {
        print "\n";
        next;
    }

    my @filt_feats = grep { $print xor $hash{$_->[0]} } @$feats;
    next if (!@filt_feats);
    my $str = Treex::Tool::ML::VowpalWabbit::Util::format_singleline(\@filt_feats, @rest);
    print $str;
}
