#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use List::MoreUtils qw/any/;

my $ranking;
GetOptions(
    "ranking" => \$ranking,
);

my %pred_costs = ();
my @true_idx = ();
my $self_idx;
while (my $line = <STDIN>) {
    chomp $line;
    if ($ranking) {
        if ($line =~ /^\s*$/) {
            my ($pred_idx, @other_idx) = sort {$pred_costs{$a} <=> $pred_costs{$b}} keys %pred_costs;
            my $true_count = scalar @true_idx;
            my $pred_count = 1;
            my $both_count = (any {$_ == $pred_idx} @true_idx) ? 1 : 0;
            if (defined $self_idx) {
                $true_count = 0 if (any {$_ == $self_idx} @true_idx);
                $pred_count = 0 if ($pred_idx == $self_idx);
                $both_count = 0 if (!$true_count && !$pred_count); 
            }
            print join " ", ($true_count, $pred_count, $both_count);
            print "\n";
            %pred_costs = (); @true_idx = (); $self_idx = undef;
        }
        else {
            my ($pred_str, $true_str) = split / /, $line;
            my ($pred_idx, $pred_cost) = split /:/, $pred_str;
            $pred_costs{$pred_idx} = $pred_cost;
            if (!@true_idx) {
                (my $true_idx_str, $self_idx) = split /-/, $true_str;
                @true_idx = split /,/, $true_idx_str;
            }
        }
    }
    else {
        my ($pred_str, $true_str) = split /\s*/, $line;
        print join " ", (1, 1, $pred_str == $true_str ? 1 : 0);
        print "\n";
    }
}
