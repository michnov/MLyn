#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use List::Util qw/sum/;

# the input and output format of the scores
my $from = "probs";     # losses
my $to = "losses_0,1";  # probs | losses
GetOptions(
    "from=s" => \$from,
    "to=s" => \$to,
);

my $res_file = $ARGV[0];
open my $res_fh, "<", $res_file;

my @results = ();
my $curr_res = {};
my $idx = 1;
while (my $line = <$res_fh>) {
    chomp $line;
    if ($line =~ /^\s*$/) {
        if (%$curr_res) {
            if ($from eq "losses" && $to eq "losses_0,1" ) {
                my $exp_sum = sum(map {exp($_)} values %$curr_res);
                $curr_res = { map {$_ => sprintf "%.5f", exp($curr_res->{$_}) / $exp_sum} keys %$curr_res };
            }
            elsif ($from eq "losses" && $to eq "losses") {
            }
            elsif ($from eq "probs" && $to eq "losses_0,1") {
                $curr_res = { map {$_ => 1 - $curr_res->{$_}} keys %$curr_res };
            }
            elsif ($from eq "probs" && $to eq "probs") {
            }
            else {
                print STDERR "Input/output format of scores not supported: $from -> $to\n";
                exit 1;
            }

            push @results, $curr_res;
            $curr_res = {};
        }
        $idx = 1;
    }
    else {
        my ($loss, $tag) = split / /, $line;
        $loss =~ s/^\d+://;
        $curr_res->{$idx} = $loss;
        $idx++;
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
