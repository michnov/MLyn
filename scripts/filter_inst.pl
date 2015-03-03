#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

my $in = '';
my $out = '';
my $multiline = 0;
my $n = undef;

GetOptions (
    "in=s" => \$in,
    "out=s" => \$out,
    "multiline=i" => \$multiline,
    "n=i" => \$n,
);

# we could use Treex::Tool::ML::TabSpace::Util but it doesn't have to be parsed in such a detailed extent
sub read_instance {
    my ($fh, $multiline) = @_;

    if ($multiline) {
        my $text = "";
        while (my $line = <$fh>) {
            $text .= $line;
            last if $line =~ /^\s*$/;
        }
        return $text;
    }
    else {
        my $line = <$fh>;
        return $line;
    }
}

if (!defined $n) {
    print $_ while (<STDIN>);
}

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

my $inst_num = 0;
while (my $inst = read_instance(*STDIN, $multiline)) {
    #print STDERR "$print $inst_num $n ".($inst_num % $n)."\n";
    if ($print xor $hash{$inst_num % $n}) {
        print $inst;
    }
    $inst_num++;
}
