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
my $probs;
GetOptions(
    "help|h" => \$help,
    "threshold:i" => \$max_loss,
    "probs" => \$probs,
);

my $USAGE = <<USAGE;
Usage: $0 [--threshold <value>] [--probs]
    - discretizes losses to 0/1 loss
    - if a threshold value is set, all examples above this value have loss 1
    - otherwise, only the examples with a minimum value turns into 0 loss
    - if the parameter <probs> is on, probabilities instead of losses are expected as an input => everything is other way round
USAGE

if ($help) {
    print $USAGE;
    exit;
}

while ( my ($feats, $losses, $tags, $comments) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN) ) {
    # turn other way round if probabilities instead of losses in the input
    $losses = [ map {-$_} @$losses ] if ($probs);
    my @new_losses;
    if (!defined $max_loss) {
        my $min_loss = min @$losses;
        @new_losses = map {$_ == $min_loss ? 0 : 1} @$losses;
    }
    else {
        # turn other way round if probabilities instead of losses in the input
        $max_loss = -$max_loss if ($probs);
        @new_losses = map {$_ <= $max_loss ? 0 : 1} @$losses;
    }
    print Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, \@new_losses, $comments);
}
