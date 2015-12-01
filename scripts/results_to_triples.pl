#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use List::Util qw/min/;
use List::MoreUtils qw/any/;

my $ranking;
GetOptions(
    "ranking" => \$ranking,
);

my %pred_costs = ();
my @true_idx = ();
my $self_idx;
while (my $line = <STDIN>) {
    chomp $line;
# TODO non-ranking adjusted to return (0, 0, 1) if we correctly guess other than a specified class
    if ($ranking) {
        if ($line =~ /^\s*$/) {
            my $min = min values %pred_costs;
            my @pred_idx = grep {$pred_costs{$_} == $min} keys %pred_costs;
            my $true_count = scalar @true_idx;
            my $pred_count = scalar @pred_idx;
            my $both_count = scalar (grep {my $idx = $_; any {$_ == $idx} @true_idx} @pred_idx);
            if (defined $self_idx) {
                $true_count = 0 if (any {$_ == $self_idx} @true_idx);
                $pred_count = 0 if (any {$_ == $self_idx} @pred_idx);
                $both_count = 1 if (!$true_count && !$pred_count); 
            }
            print join " ", ($true_count, $pred_count, $both_count);
            print "\n";
            %pred_costs = (); @true_idx = (); $self_idx = undef;
        }
        elsif ($line =~ /^\d+:-?\d+\.\d+ \d+-\d+$/) {
            my ($pred_str, $true_str) = split / /, $line;
            my ($pred_idx, $pred_cost) = split /:/, $pred_str;
            $pred_costs{$pred_idx} = $pred_cost;
            if (!@true_idx) {
                (my $true_idx_str, $self_idx) = split /-/, $true_str;
                @true_idx = split /,/, $true_idx_str;
            }
        }
    }
    else {
        my ($true_str, $pred_str) = split /\s+/, $line;
        if ($true_str =~ /-/) {
            ($true_str, my $fscore_label) = split /-/, $true_str;
            print join " ", ($true_str == $fscore_label ? 1 : 0, $pred_str == $fscore_label ? 1 : 0, $pred_str == $true_str ? 1 : 0);
        }
        else {
            print join " ", (1, 1, $pred_str == $true_str ? 1 : 0);
        }
        print "\n";
    }
}

__END__

=encoding utf-8

=head1 NAME 

results_to_triples.pl

=head1 DESCRIPTION

TODO this should be explained and reformulated

Transforms a result file produced by ML Framework to a format, where each instance is represented by a tab-separated triple on a single line.
For ranking tasks, especially, it reduces multiline format of results to a single line per instance.

The input format consists of two columns, predicted label and true labels. The true labels are separated by comma, if there is more than one.
Moreover, the whole true labels string can be followed by information, for which label precision, recall and f-score will be calculated (such
label will be denoted as "focused"). This information is separated by a hyphen from the rest.

Regarding the output format, the three items of each triple represent:
1) a number of 

=head1 PARAMETERS

=over

=item C<--ranking>

A flag indicating that a multiline input format is expected.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
