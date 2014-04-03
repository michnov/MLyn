#!/usr/bin/env perl

use warnings;
use strict;

use List::Util qw/max/;

sub date {
    my (@rest) = @_;
    return "<h1>" . (join "\t", @rest) . "</h1>";
}

sub feats {
    my (@rest) = @_;
    return "<h3>" . (join "\t", @rest) . "</h3>";
}

sub info {
    my (@rest) = @_;
    return "<p>" . (join "\t", @rest) . "</p>";
}

sub ml_method {
    my (@rest) = @_;
    my @ths = map {"<th style=\"font-size: 70%\">$_</th>"} @rest;
    return "<tr>" . (join "\t", @ths) . "</tr>";
}

use Data::Dumper;

sub results {
    my ($rowspan, @rest) = @_;
    my $rs_str = "";
    if (defined $rowspan) {
        $rs_str = "rowspan=\"$rowspan\"";
    }
    my @res = map { my @chunks = split / /, $_; \@chunks } @rest;
    my $max_perc = max( map {$_->[0] || 0} @res);
    my @tds = map {
        my ($perc, $ratio) = @$_;
        if (!defined $perc) {
            $perc = 0;
            $ratio = "()";
        }
        if (!defined $ratio) {
            $ratio = "";
        }
        my $color = "";
        if ($perc == $max_perc) {
            $color = "color: red;";
        }
        "<td $rs_str style=\"text-align: right;$color\"><a title=\"$ratio\">$perc</a></td>"
    } @res;
    return "<tr>" . (join "\t", @tds) . "</p>";
}

sub _count_rowspan {
    my ($lines, $i) = @_;

    my $span = 1;
    while (defined $lines->[$i+$span] && $lines->[$i+$span][0] =~ /^\s*$/) {
        $span++;
    }
    return $span;
}

my $html_str = "";

my @lines = <STDIN>;
my @table_lines = map {chomp $_; [split /\t/, $_]} @lines; 


for (my $i = 0; $i < @table_lines; $i++) {

    my ($label, @rest) = @{$table_lines[$i]};
    if ($label eq "DATE:") {
        $html_str .= date(@rest);
    }
    elsif ($label eq "FEATS:") {
        $html_str .= feats(@rest);
    }
    elsif ($label eq "INFO:") {
        $html_str .= info(@rest);
    }
    elsif ($label eq "ML_METHOD:") {
        $html_str .= "<table>\n";
        $html_str .= ml_method(@rest);
    }
    elsif ($label eq "TRAIN:") {
        my $rowspan = _count_rowspan(\@table_lines, $i);
        $html_str .= results($rowspan, @rest);
    }
    elsif ($label eq "DEV:") {
        my $rowspan = _count_rowspan(\@table_lines, $i);
        $html_str .= results($rowspan, @rest);
        $html_str .= "\n</table>";
    }
    elsif ($label eq "") {
        $html_str .= results(undef, @rest);
        $html_str .= "\n</table>";
    }
    
    $html_str .= "\n";
}
print $html_str;
