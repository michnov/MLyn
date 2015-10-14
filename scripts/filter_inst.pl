#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

my $in = undef;
my $out = undef;
my $multiline = 0;
my $n = undef;

GetOptions (
    "in=s" => \$in,
    "out=s" => \$out,
    "multiline=i" => \$multiline,
    "n=i" => \$n,
);

sub prepare_index_hash {
    my ($index_str) = @_;
    # it can be a file path
    if (-f $index_str) {
        open my $fh, "<", $index_str;
        $index_str = join "", (<$fh>);
    }
    my %index_hash = map {$_ => 1} split /[,\s]/, $index_str;
    return \%index_hash;
}

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

#if (!defined $n) {
#    print $_ while (<STDIN>);
#}

my $print;
my $hash;
if (defined $in) {
    $print = 0;
    $hash = prepare_index_hash($in);
} elsif (defined $out) {
    $print = 1;
    $hash = prepare_index_hash($out);
} else {
    print $_ while (<STDIN>);
}

my $inst_num = 0;
while (my $inst = read_instance(*STDIN, $multiline)) {
    #print STDERR "$print $inst_num $n ".($inst_num % $n)."\n";
    if (defined $n) {
        if ($print xor $hash->{$inst_num % $n}) {
            print $inst;
        }
    }
    else {
        if ($print xor $hash->{$inst_num}) {
            print $inst;
        }
    }
    $inst_num++;
}
