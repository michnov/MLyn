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
    my @ths = map {"<th style=\"font-size:70%\">$_</th>"} @rest;
    return "<tr>" . (join "\t", @ths) . "</tr>";
}

use Data::Dumper;

sub results {
    my ($rest, $tr_style) = @_;
    $tr_style = "" if (!defined $tr_style);
    my @res = map { my @chunks = split / /, $_; \@chunks } @$rest;
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
        "<td style=\"text-align:right; $color\"><a title=\"$ratio\">$perc</a></td>"
    } @res;
    return "<tr $tr_style>" . (join "\t", @tds) . "</tr>";
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


my $rowspan = 1;
my $label;
for (my $i = 0; $i < @table_lines; $i++) {

    my ($label_line, @rest) = @{$table_lines[$i]};
    if ($rowspan == 1) {
        $label = $label_line;
        $rowspan = _count_rowspan(\@table_lines, $i);
    }
    else {
        $rowspan--;
    }

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
        $html_str .= "<table style=\"border-collapse: collapse\">\n";
        $html_str .= ml_method(@rest);
    }
    elsif ($label eq "TRAIN:") {
        my $tr_style = "";
        if ($rowspan == 1) {
            $tr_style = "style=\"border-style: none none solid none; border-width: 2px;\"";
        }
        $html_str .= results(\@rest, $tr_style);
    }
    elsif ($label eq "DEV:") {
        $html_str .= results(\@rest);
        if ($rowspan == 1) {
            $html_str .= "\n</table>";
        }
    }
    
    $html_str .= "\n";
}
print $html_str;
