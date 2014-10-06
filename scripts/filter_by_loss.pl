#!/usr/bin/env perl

use warnings;
use strict;

use Treex::Tool::ML::VowpalWabbit::Util;
use List::Util qw/min/;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my $USAGE = <<USAGE;
Usage: $0 <upper_loss_limit>
    - filters out instances with a minimum loss greater than upper_loss_limit
    - works for multiline instances so far
USAGE

if (@ARGV < 1) {
    print $USAGE;
    exit;
}
my $loss_limit = $ARGV[0];

my $all_count = 0;
my $ok_count = 0;

while ( my ($feats, $losses, $tags, $comments) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN) ) {
    my $min_loss = min @$losses;
    #print STDERR "$min_loss\n";
    if ($min_loss < $loss_limit) {
        print Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comments);
        $ok_count++;
    }
    $all_count++;
    if ($all_count % 1000 == 0) {
        print STDERR "FILTER_BY_LOSS: filtered $ok_count out of $all_count, so far\n";
    }
}
