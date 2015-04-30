#!/usr/bin/env perl

use warnings;
use strict;

my $count = 0;
my $prev_empty = 1;
while (<STDIN>) {
    if ($prev_empty && $_ !~ /^\s*$/) {
        $count++;
        $prev_empty = 0;
    } 
    elsif (!$prev_empty && $_ =~ /^\s*$/) {
        $prev_empty = 1;
    }
}
print $count ."\n";
