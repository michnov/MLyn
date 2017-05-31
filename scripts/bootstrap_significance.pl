#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use List::Util qw/sum/;

use EvalTriples;
use Statistics::Robust::Bootstrap;

my $TYPE = "lenient";

my $iter_count = 0;

my $boot_alpha = 0.05;
my $boot_n = 1000;

GetOptions(
    "alpha=f" => \$boot_alpha,
    "n=i" => \$boot_n,
);

sub prf_count {
    my ($true, $pred, $both) = @_;
    return EvalTriples::prf_lenient($true, $pred, $both) if ($TYPE eq "lenient");
}

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

    my $all_rec_num_1 = sum map {$_->[0]} @$results;
    my $all_rec_denom_1 = sum map {$_->[1]} @$results;
    my $all_prec_num_1 = sum map {$_->[2]} @$results;
    my $all_prec_denom_1 = sum map {$_->[3]} @$results;
    my ($p1, $r1, $f1) = EvalTriples::prf($all_rec_num_1, $all_rec_denom_1, $all_prec_num_1, $all_prec_denom_1);

    if (defined $results->[0][4]) {
        my $all_rec_num_2 = sum map {$_->[4]} @$results;
        my $all_rec_denom_2 = sum map {$_->[5]} @$results;
        my $all_prec_num_2 = sum map {$_->[6]} @$results;
        my $all_prec_denom_2 = sum map {$_->[7]} @$results;
        my ($p2, $r2, $f2) = EvalTriples::prf($all_rec_num_2, $all_rec_denom_2, $all_prec_num_2, $all_prec_denom_2);

        return ($f2 - $f1);
    }
    return $f1;
}

sub _extract_from_res {
    my ($line1, $line2) = @_;
    chomp $line1;
    my ($true1, $pred1, $both1) = split / /, $line1;
    my @res = prf_count($true1, $pred1, $both1);
    if (defined $line2) {
        chomp $line2;
        my ($true2, $pred2, $both2) = split / /, $line2;
        push @res, prf_count($true2, $pred2, $both2);
    }
    return \@res;
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
