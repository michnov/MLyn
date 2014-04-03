#!/usr/bin/env perl

use strict;
use warnings;

sub print_line {
    my ($str, $feat_descr) = @_;

    $str =~ s/,\s*/,/g;
    $str =~ s/^\s+//g;
    $str =~ s/\s+$//g;
    $str =~ s/\s+/,/g;
   
    if (defined $feat_descr) {
        $feat_descr =~ s/^#\s*//g;
        $feat_descr =~ s/\s/__WS__/g;
    }
    else {
        $feat_descr = $str;
        $feat_descr =~ s/,/,__WS__/g;
    }
    
    print $str . "#" . $feat_descr . "\n";
}

my $curr_feat_str = undef;
my $prev_comment = undef;
my $feat_descr = undef;

while (<STDIN>) {
    chomp $_;
    if ($_ =~ /^#/) {
        $prev_comment = $_;
        next;
    }
    if ($_ =~ /^\s*$/) {
        $prev_comment = undef;
        next;
    }

    if ($_ =~ /^\s+(\S.*)$/) {
        $curr_feat_str .= " " . $1;
    }
    else {
        if (defined $curr_feat_str) {
            print_line($curr_feat_str, $feat_descr);
        }
        $feat_descr = $prev_comment;
        $curr_feat_str = $_;
    }
}
print_line($curr_feat_str, $feat_descr);
