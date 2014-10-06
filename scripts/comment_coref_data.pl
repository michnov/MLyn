#!/usr/bin/env perl

use warnings;
use strict;

use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Block::Print::CorefData;
use Data::Dumper;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

while ( my ($feats, $losses, $tags, $comments) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN, {parse_feats => 'pair'}) ) {
    $comments = Treex::Block::Print::CorefData::comments_from_feats($feats);
    #print STDERR Dumper($instance);
    #print STDERR Dumper($comments);
    print Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comments);
}
