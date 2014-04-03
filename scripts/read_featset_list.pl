#!/usr/bin/env perl

use strict;
use warnings;

sub print_line {
    my ($str) = @_;

    $str =~ s/,\s*/,/g;
    $str =~ s/^\s+//g;
    $str =~ s/\s+$//g;
    $str =~ s/\s+/,/g;
    print $str . "\n";
}

my $curr_feat_str = undef;

while (<STDIN>) {
    chomp $_;
    next if ($_ =~ /^#/);
    next if ($_ =~ /^\s*$/);

    if ($_ =~ /^\s+(\S.*)$/) {
        $curr_feat_str .= " " . $1;
    }
    else {
        if (defined $curr_feat_str) {
            print_line($curr_feat_str);
        }
        $curr_feat_str = $_;
    }
}
print_line($curr_feat_str);
