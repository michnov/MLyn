#!/usr/bin/env perl

use warnings;
use strict;

use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Block::Print::CorefData;
use Data::Dumper;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

while ( my ($instance, $comments) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN, {split_key_val => 1}) ) {
    my ($feats, $losses) = @$instance;
    $comments = Treex::Block::Print::CorefData::comments_from_feats($feats);
    #print STDERR Dumper($instance);
    #print STDERR Dumper($comments);
    print Treex::Tool::ML::VowpalWabbit::Util::format_multiline(@$instance, $comments);
}
