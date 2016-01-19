#!/usr/bin/env perl

use strict;
use warnings;

my $res_file = $ARGV[0];
open my $res_fh, "<", $res_file;

my @results = ();
my $curr_res = {};
while (my $line = <$res_fh>) {
    chomp $line;
    if ($line =~ /^\s*$/) {
        if (%$curr_res) {
            push @results, $curr_res;
            $curr_res = {};
        }
    }
    else {
        my ($idx_loss, $tag) = split / /, $line;
        my ($idx, $loss) = split /:/, $idx_loss;
        $curr_res->{$idx} = $loss;
    }
}
close $res_fh;

my $instance_num = 0;

$curr_res = shift @results;
while (my $line = <STDIN>) {
    chomp $line;
    if ($line =~ /^\s*$/) {
        print "\n";
        $curr_res = shift @results;
        $instance_num++;
        if ($instance_num % 100000 == 0) {
            print STDERR "Processing instane no. $instance_num\n";
        }
        next;
    }
    my ($first, @rest) = split / /, $line;
    if ($first =~ /^shared/) {
        print $line;
        print "\n";
    }
    else {
        my ($idx, $old_loss) = split /:/, $first;
        my $new_loss = $curr_res->{$idx} // "1";
        print join " ", ($idx.":".$new_loss, @rest);
        print "\n";
    }
}
