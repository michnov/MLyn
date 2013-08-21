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
    my (@rest) = @_;
    my @res = map { my @chunks = split / /, $_; \@chunks } @rest;
    my $max_perc = max( map {$_->[0] || 0} @res);
    my @tds = map {
        my ($perc, $ratio) = @$_;
        if (!defined $perc) {
            $perc = 0;
            $ratio = "()";
        }
        my $color = "";
        if ($perc == $max_perc) {
            $color = "color: red;";
        }
        "<td style=\"text-align: right;$color\"><a title=\"$ratio\">$perc</a></td>"
    } @res;
    return "<tr>" . (join "\t", @tds) . "</p>";
}

my $html_str = "";

while (<STDIN>) {
    chomp $_;

    my ($label, @rest) = split /\t/, $_;
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
        $html_str .= results(@rest);
    }
    elsif ($label eq "DEV:") {
        $html_str .= results(@rest);
        $html_str .= "\n</table>";
    }
    
    $html_str .= "\n";
}
print $html_str;
