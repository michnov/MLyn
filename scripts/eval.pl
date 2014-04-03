#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use EvalTriples;

my $TYPE = "lenient";

my $print_acc = 0;
my $print_prf = 0;
GetOptions(
    "acc" => \$print_acc,
    "prf" => \$print_prf,
);
$print_acc = 1 if (!$print_acc && !$print_prf);

my $args = {
    acc => $print_acc,
    prf => $print_prf,
    $TYPE => 1,
    format => 1
};
my $stats = EvalTriples::eval(*STDIN, $args);

if ($print_acc) {
    print join(" ", @{$stats->{acc}{$TYPE}}) . "\n";
}
if ($print_prf) {
    my @prf_strs = @{$stats->{prf}{$TYPE}};
    print join(" ", @prf_strs[0 .. 1]) . "\n";
    print join(" ", @prf_strs[2 .. 3]) . "\n";
    print join(" ", ($prf_strs[4], "")) . "\n";
}
