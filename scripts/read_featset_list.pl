#!/usr/bin/env perl

use strict;
use warnings;

sub print_line {
    my ($feats, $feat_descr) = @_;

    if (defined $feat_descr) {
        $feat_descr =~ s/\s/__WS__/g;
    }
    else {
        $feat_descr = join ",__WS__", @$feats;
    }
    my $str = join ",", @$feats; 
    print $str . "#" . $feat_descr . "\n";
}

sub featstr_to_list {
    my ($str) = @_;

    $str =~ s/,\s*/,/g;
    $str =~ s/^\s+//g;
    $str =~ s/\s+$//g;

    return split /\s+/, $str; 
}

sub replace_featset_refs {
    my ($feats, $named_featsets) = @_;
    return map { if ($_ =~ /^@(.*)$/) { @{$named_featsets->{$1}} } else {$_} } @$feats;
}

sub extract_info {
    my ($str) = @_;
    
    $str =~ s/^#\s*//g;
    my $feat_name = undef;
    if ($str =~ /^(.+):/) {
        $feat_name = $1;
        $feat_name =~ s/\s+$//;
    }
    return ($feat_name, $str);
}

my %named_featsets = ();

my $curr_feat_str = undef;
my $prev_comment = undef;
my ($feat_name, $feat_descr) = undef;

my $experiments_section = 0;

while (<STDIN>) {
    chomp $_;
    if ($_ =~ /^#/) {
        $prev_comment = $_;
        next;
    }
    if ($_ =~ /^\s*$/) {
        $prev_comment = undef;
        next;
    }
    
    if ($_ =~ /^\s+(\S.*)$/) {
        $curr_feat_str .= " " . $1;
    }
    else {
        if (defined $curr_feat_str) {
            my @feats = featstr_to_list($curr_feat_str);
            @feats = replace_featset_refs(\@feats, \%named_featsets);
            if (defined $feat_name) {
                $named_featsets{$feat_name} = \@feats;
            }
            if ($experiments_section) {
                print_line(\@feats, $feat_descr);
            }
        }
        if ($_ eq "<<<EXPERIMENTS>>>") {
            $experiments_section = 1;
            $curr_feat_str = undef;
            next;
        }
        ($feat_name, $feat_descr) = extract_info($prev_comment);
        $curr_feat_str = $_;
    }
}
my @feats = featstr_to_list($curr_feat_str);
@feats = replace_featset_refs(\@feats, \%named_featsets);
if ($experiments_section) {
    print_line(\@feats, $feat_descr);
}
