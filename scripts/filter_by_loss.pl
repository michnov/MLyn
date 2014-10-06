#!/usr/bin/perl

use strict;
use warnings;

if (@ARGV < 1) {
    print "Usage: $0 <upper_score_limit>\n";
}

my $score_limit = $ARGV[0];

my @instances = ();
my $max_score = undef;
while (<STDIN>) {
    chomp $_;
    if ($_ =~ /^\s*$/) {
        if (defined $max_score && ($max_score < $score_limit)) {
            print join "\n", @instances;
            print "\n\n";
        }
        @instances = ();
        $max_score = undef;
        next;
    }
    push @instances, $_;
    my ($score, @rest) = split /\t/, $_;
#    print STDERR "$score\n";
    if ($score ne '__SHARED__' && (!defined $max_score || $score < $max_score)) {
        $max_score = $score;
    }
}
if (defined $max_score && ($max_score < $score_limit)) {
    print join "\n", @instances;
    print "\n\n";
}
