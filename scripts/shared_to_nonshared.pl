#!/usr/bin/env perl

use warnings;
use strict;

sub parse_instance {
    my ($line) = @_;
    
    chomp $line;
    my ($first, @rest) = split /\t/, $line;

    my %ns_to_feats = ();
    my ($label, @ns_feats) = split /\|/, $first;
    foreach my $ns_feat (@ns_feats) {
        my ($ns, @feats) = split / +/, $ns_feat;
        my $old_feats = $ns_to_feats{$ns} // [];
        push @$old_feats, @feats;
        $ns_to_feats{$ns} = $old_feats;
    }

    return ($label, \%ns_to_feats, \@rest);
}

sub print_instance {
    my ($label, $ns_to_feats, $rest) = @_;

    my $ns_str = join " ", map {"|".$_." ".(join " ", @{$ns_to_feats->{$_}})} keys %$ns_to_feats;
    print join "\t", ($label.$ns_str, @$rest);
    print "\n";
}

sub merge_ns {
    my (@nss) = @_;

    my $merged_ns = {};
    foreach my $ns (@nss) {
        foreach my $ns_key (keys %$ns) {
            my $old_feats = $merged_ns->{$ns_key} // [];
            push @$old_feats, @{$ns->{$ns_key}};
            $merged_ns->{$ns_key} = $old_feats;
        }
    }
    return $merged_ns;
}

my $skip_all = undef;
while (my $line = <>) {
    
    my ($shared_label, $shared_ns_to_feats, $shared_rest) = parse_instance($line);
    if (!defined $skip_all && $shared_label !~ /^shared/) {
        $skip_all = 1;
        print $line;
        while ($line = <>) {
            print $line;
        }
        next;
    }
    else {
        $skip_all = 0;
    }
    if ($shared_label !~ /^shared/) {
        next;
    }

    $line = <>;
    while (defined $line && $line !~ /^\s*$/) {
        my ($label, $ns_to_feats, $rest) = parse_instance($line);
        my $merged_ns = merge_ns($ns_to_feats, $shared_ns_to_feats);
        print_instance($label, $merged_ns, $rest);
        
        $line = <>;
    }

    print "\n";
}
