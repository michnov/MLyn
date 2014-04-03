#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use List::MoreUtils qw/any/;

my $ranking;
GetOptions(
    "ranking" => \$ranking,
);

while (my $line = <STDIN>) {
    chomp $line;
    next if ($line =~ /^\s*$/);
    my ($pred_str, $true_str) = split / /, $line;
    
    if ($ranking) {
        my $pred_idx = int($pred_str);
        next if ($pred_idx == 0);

        my ($true_idx_str, $self_idx) = split /-/, $true_str;
        my @true_idx = split /,/, $true_idx_str;

        my $true_count = scalar @true_idx;
        my $pred_count = 1;
        my $both_count = (any {$_ == $pred_idx} @true_idx) ? 1 : 0;
        if (defined $self_idx) {
            $true_count = 0 if (any {$_ == $self_idx} @true_idx);
            $pred_count = 0 if ($pred_idx == $self_idx);
            $both_count = 0 if (!$true_count && !$pred_count); 
        }

        print join " ", ($true_count, $pred_count, $both_count);
    }
    else {
        print join " ", (1, 1, $pred_str == $true_str ? 1 : 0);
    }
    print "\n";
}
