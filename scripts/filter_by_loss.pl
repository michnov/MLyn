#!/usr/bin/env perl

use warnings;
use strict;

use Treex::Tool::ML::VowpalWabbit::Util;
use List::Util qw/sum/;
use Getopt::Long;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my $default_diff_value = -10;

my $USAGE = <<USAGE;
Usage: $0 [--threshold|t <metrics_threshold>] [--metrics|m <min_loss|diff_loss|avg_diff_loss>]
    - filters out instances with a loss-based metrics greater than upper_loss_limit
    - works only for multiline instances so far
    
    --metrics|-m
        - specifies the type of metrics used
        - min_loss: minimum loss in a given instance; default
        - diff_loss: difference between the lowest and the second lowest loss; -10 if the instance consists of a single candidate
        - avg_diff_loss: difference between the minimum loss and the average value of the rest losses within the instance; -10 if the instance consists of a single candidate
    --threshold|-t
        - specifies the maximum value of metrics to pass the instance through
        - default: 0
    --help|-h
        - prints this help
USAGE

my $metrics = "min_loss";
my $threshold = 0;
my $help;
GetOptions(
    "metrics|m=s" => \$metrics,
    "threshold|t=f" => \$threshold,
    "help|h" => \$help,
);

if ($help) {
    print $USAGE;
    exit;
}

my $all_count = 0;
my $ok_count = 0;

while ( my ($feats, $losses, $tags, $comments) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN) ) {

    my @sorted_losses = sort {$a <=> $b} @$losses;
    my ($min, @rest) = @sorted_losses;

    my $metrics_value;
    if ($metrics eq "diff_loss") {
        $metrics_value = @rest ? $min - $rest[0] : $default_diff_value;
    }
    elsif ($metrics eq "avg_diff_loss") {
        $metrics_value = @rest ? $min - (sum @rest / scalar @rest) : $default_diff_value;
    }
    else {
        $metrics_value = $min;
    }
    
    #print STDERR "$min_loss\n";
    if ($metrics_value <= $threshold) {
        print Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comments);
        $ok_count++;
    }
    $all_count++;
    if ($all_count % 1000 == 0) {
        print STDERR "FILTER_BY_LOSS: filtered $ok_count out of $all_count, so far\n";
    }
}
