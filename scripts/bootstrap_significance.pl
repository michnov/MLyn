#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use List::Util qw/sum/;

use EvalTriples;
use Statistics::Robust::Bootstrap;

my $iter_count = 0;

my $boot_alpha = 0.05;
my $boot_n = 1000;

GetOptions(
    "alpha=f" => \$boot_alpha,
    "n=i" => \$boot_n,
);

sub _get_lines {
    my ($path) = @_;

    open my $res_fh, "<:utf8", $path;
    my @lines = <$res_fh>;
    return @lines;
}

sub eval_results {
    my ($results) = @_;

    $iter_count++;
    if ($iter_count % 1000 == 0) {
        print STDERR "Processed $iter_count samples.\n";
    }

    my $all_pred1 = sum map {$_->{pred1}} @$results;
    my $all_true1 = sum map {$_->{true1}} @$results;
    my $all_both1 = sum map {$_->{both1}} @$results;
    my ($p1, $r1, $f1) = EvalTriples::prf($all_true1, $all_pred1, $all_both1);

    if (defined $results->[0]->{pred2}) {
        my $all_pred2 = sum map {$_->{pred2}} @$results;
        my $all_true2 = sum map {$_->{true2}} @$results;
        my $all_both2 = sum map {$_->{both2}} @$results;
        my ($p2, $r2, $f2) = EvalTriples::prf($all_true2, $all_pred2, $all_both2);

        return ($f2 - $f1);
    }
    return $f1;
}

sub _extract_from_res {
    my ($line1, $line2) = @_;
    chomp $line1;
    my ($true1, $pred1, $both1) = split / /, $line1;
    my %res = (
        pred1 => $pred1,
        true1 => $true1,
        both1 => $both1,
    );
    if (defined $line2) {
        chomp $line2;
        my ($true2, $pred2, $both2) = split / /, $line2;
        %res = ( %res,
            pred2 => $pred2,
            true2 => $true2,
            both2 => $both2,
        );
    }
    return \%res;
}

my $USAGE = <<USAGE;
Usage: $0 <result_file_1>
        - a confidence interval computed by bootstrapping
       $0 <result_file_1> <result_file_2>
        - a confidence interval of difference computed by bootstrapping
USAGE

my @results;
if (@ARGV == 1) {
    my @lines = _get_lines($ARGV[0]);
    @results = map {_extract_from_res($lines[$_])} 0 .. $#lines;
}
elsif (@ARGV == 2) {
    my @lines1 = _get_lines($ARGV[0]);
    my @lines2 = _get_lines($ARGV[1]);
    if (@lines1 != @lines2) {
        printf STDERR "Result files must have the same number of instances: %d <> %d", @lines1, @lines2;
        exit;
    }
    @results = map {_extract_from_res($lines1[$_], $lines2[$_])} 0 .. $#lines1;
}
else {
    print STDERR $USAGE;
    exit;
}

my $f = \&eval_results;
my ($low, $high) = Statistics::Robust::Bootstrap::onesample(\@results, $f, $boot_alpha, $boot_n);

print "F-measure confidence interval ($boot_n-sample bootstrapping)\n";
printf "(%.2f%% ; %.2f%%)\n", $low * 100, $high * 100;
