#!/usr/bin/env perl

use warnings;
use strict;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

use Treex::Tool::Compress::Index;

my $out_indexer = Treex::Tool::Compress::Index->new();
my $path = shift @ARGV;

if (-f $path) {
    $out_indexer->load($path);
}

my @instances = ();
my %classes = ();

while (<STDIN>) {
    chomp $_;

    my ($class, @rest) = split /\t/, $_;
    my $index = $out_indexer->get_index($class);
    print join "\t", ( $index, @rest);
    print "\n";
}

$out_indexer->save($path);
