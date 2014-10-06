#!/usr/bin/env perl

use warnings;
use strict;

use List::Util qw/max/;
use Data::Dumper;

sub date {
    my (@rest) = @_;
    my $str = "<h1>" . shift @rest;
    if (@rest) {
        $str .= "<span style=\"font-size:50%; color:DarkGreen; left:-20px\">". (join "\t", @rest) ."</span>";
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

sub info {
    my (@rest) = @_;
    return "<p>" . (join "\t", @rest) . "</p>";
}

sub ml_method {
    my ($rest, $colspans) = @_;
    print STDERR Dumper($rest, $colspans);
    my @spans_str = @$colspans ? map {"colspan=\"$colspans->[$_]\""} 0 .. $#$colspans
                               : map {""} @$rest;
    my @ths = map {"<th $spans_str[$_] style=\"font-size:70%\">$rest->[$_]</th>"} 0 .. $#$rest;
    return "<tr>" . (join "\t", @ths) . "</tr>";
}

sub iter {
    my (@rest) = @_;
    return "<tr>" . (join "\t", map {"<th style=\"font-size:60%\">$_</th>"} @rest) . "</tr>";
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
        "<td style=\"padding-right:7px; text-align:right; $color\"><a title=\"$ratio\">$perc</a></td>"
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

sub _count_colspans {
    my ($lines, $i) = @_;

    my @colspans = ();
    my $next_label = $lines->[$i+1][0];
    return () if ($next_label eq "TRAIN:");
    
    my $l = 0;
    foreach my $item (@{$lines->[$i+1]}) {
        if ($item eq $next_label) {
            if ($l) {
                push @colspans, $l; 
            }
            $l = 0;
        }
        else {
            $l++;
        }
    }
    push @colspans, $l;
    return @colspans;
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
        $html_str .= "<table style=\"border-collapse: collapse;\">\n";
        my @colspans = _count_colspans(\@table_lines, $i);
        $html_str .= ml_method(\@rest, \@colspans);
    }
    elsif ($label eq "ITER") {
        $html_str .= iter(@rest);
    }
    elsif ($label eq "TRAIN:") {
        my $tr_style = "";
        if ($rowspan == 1) {
            $tr_style = "style=\"border-style: none none solid none; border-width: 2px;\"";
        }
        $html_str .= results(\@rest, $tr_style);
    }
    elsif ($label eq "DEV:" || $label eq "TEST:") {
        $html_str .= results(\@rest);
        if ($rowspan == 1) {
            $html_str .= "\n</table>";
        }
    }
    
    $html_str .= "\n";
}
print $html_str;
