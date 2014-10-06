#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use Treex::Tool::ML::VowpalWabbit::Util;
use List::Util qw/min/;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my $help;
my $max_loss;
GetOptions(
    "help|h" => \$help,
    "max-positive-loss:i" => \$max_loss,
);

my $USAGE = <<USAGE;
Usage: $0 [--max-positive-loss <value>]
    - discretizes losses to 0/1 loss
    - if a max-positive-loss value is set, all examples above this value have loss 1
    - otherwise, only the examples with a minimum value turns into 0 loss
USAGE

if ($help) {
    print $USAGE;
    exit;
}

while ( my ($feats, $losses, $tags, $comments) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN) ) {
    my @new_losses;
    if (!defined $max_loss) {
        my $min_loss = min @$losses;
        @new_losses = map {$_ == $min_loss ? 0 : 1} @$losses;
    }
    else {
        @new_losses = map {$_ <= $max_loss ? 0 : 1} @$losses;
    }
    print Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, \@new_losses, $comments);
}
