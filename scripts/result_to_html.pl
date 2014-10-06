#!/usr/bin/env perl

use warnings;
use strict;

use List::Util qw/max/;
use Data::Dumper;

sub info {
    my (@rest) = @_;
    my $str = "<h1>" . shift @rest;
    $str .= "<span style=\"font-size:50%; color:Blue; position:relative; left:10px\">". (shift @rest) ."</span>";
    if (@rest) {
        $str .= "<span style=\"font-size:50%; color:DarkGreen; position:relative; left:20px\">". (join "\t", @rest) ."</span>";
    }
    $str .= "</h1>";
    return $str;
}

sub feats {
    my (@rest) = @_;
    if (@rest == 2) {
        return "<h3><a title=\"". ($rest[1] // "") . "\">" . $rest[0] . "</a></h3>";
    } elsif (@rest == 3) {
        return "<h3><a title=\"". ($rest[2] // "") . "\">" . $rest[0] . "</a><span style=\"font-size:80%; left:-20px\">$rest[1]</span></h3>";
    }
}

sub ml_method {
    my ($rest, $colspans) = @_;
    my @ths = ();
    for (my $i = 0; $i < @$rest; $i++) {
        my $item = $rest->[$i];
        (my $border_style, $item) = _border_style($item);
        my $colspan_str = @$colspans ? "colspan=\"$colspans->[$i]\"" : "";
        my $th_str = "<th $colspan_str style=\"font-size:70%; $border_style\">$item</th>";
        push @ths, $th_str;
    }
    return "<tr>" . (join "\t", @ths) . "</tr>";
}

sub iter {
    my (@rest) = @_;
    my @ths = map {
        my $item = $_;
        (my $border_style, $item) = _border_style($item);
        "<th style=\"font-size:60%; $border_style\">$_</th>"
    } @rest;
    return "<tr>" . (join "\t", @ths) . "</tr>";
}


sub results {
    my ($rest, $tr_style) = @_;
    $tr_style = "" if (!defined $tr_style);
    my $max_perc = max( map {my @a = split / /, $_; $a[0] || 0} @$rest);
    my @tds = map {
        my $item = $_;
        (my $border_style, $item) = _border_style($item);
        my ($perc, $ratio) = split / /, $item;
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
        "<td style=\"padding-right:7px; text-align:right; $color $border_style\"><a title=\"$ratio\">$perc</a></td>"
    } @$rest;
    return "<tr $tr_style>" . (join "\t", @tds) . "</tr>";
}

sub _border_style {
    my ($str) = @_;
    my $style = ($str =~ /\|$/) ? "border-right:1px solid;" : "";
    $str =~ s/\|$//;
    return ($style, $str);
}

sub _count_rowspan {
    my ($lines, $i) = @_;

    my $span = 1;
    while (defined $lines->[$i+$span] && $lines->[$i+$span][0] =~ /^\s*$/) {
        $span++;
    }
    return $span;
}

sub _count_colspans {
    my ($lines, $i) = @_;

    my @colspans = ();
    my $next_label = $lines->[$i+1][0];
    return () if ($next_label eq "TRAIN:");

    my $l = 0;
    for (my $j = 1; $j < @{$lines->[$i+1]}; $j++) {
        $l++;
        if ($lines->[$i+1][$j] =~ /\|$/) {
            push @colspans, $l;
            $l = 0;
        }
    }
    push @colspans, $l;
    return @colspans;
}

my $html_str = "";

my @lines = <STDIN>;
my @table_lines = map {chomp $_; [split /\t/, $_]} @lines; 


my $rowspan = 1;
my $multicols_count = 0;
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

    if ($label eq "INFO:") {
        $html_str .= info(@rest);
    }
    elsif ($label eq "FEATS:") {
        $html_str .= feats(@rest);
    }
    elsif ($label eq "ML_METHOD:") {
        $html_str .= "<table style=\"border-collapse: collapse;\">\n";
        my @colspans = _count_colspans(\@table_lines, $i);
        $html_str .= ml_method(\@rest, \@colspans);
    }
    elsif ($label eq "ITER") {
        $html_str .= iter(@rest);
    }
    elsif ($label =~ /^TRAIN/) {
        my $tr_style = "";
        if ($rowspan == 1) {
            $tr_style = "style=\"border-style: none none solid none; border-width: 2px;\"";
        }
        $html_str .= results(\@rest, $tr_style);
    }
    elsif ($label eq "TEST_L1:") {
        my $tr_style = "";
        if ($rowspan == 1) {
            $tr_style = "style=\"border-style: none none solid none; border-width: 4px;\"";
        }
        $html_str .= results(\@rest, $tr_style);
    }
    elsif ($label eq "DEV:" || $label eq "TEST:" || $label eq "TEST_L2:") {
        $html_str .= results(\@rest);
        if ($rowspan == 1) {
            $html_str .= "\n</table>";
        }
    }
    
    $html_str .= "\n";
}
print $html_str;
