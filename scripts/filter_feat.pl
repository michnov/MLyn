#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::ML::VowpalWabbit::Util;
use Getopt::Long;
use Data::Dumper;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my $in = '';
my $out = '';

GetOptions (
    "in=s" => \$in,
    "out=s" => \$out,
);

my %in_hash = map {$_ => 1} split /,/, $in;
my %out_hash = map {$_ => 1} split /,/, $out;

my $print;
my %hash;
if (keys %in_hash > 0) {
    $print = 0;
    %hash = %in_hash;
} elsif (keys %out_hash > 0) {
    $print = 1;
    %hash = %out_hash;
} else {
    print $_ while (<STDIN>);
}

while ( my ($feats, @rest) = Treex::Tool::ML::VowpalWabbit::Util::parse_singleline(*STDIN, {parse_feats => 'pair'}) ) {
    if (!@$feats) {
        print "\n";
        next;
    }

    my @filt_feats;
    my $curr_ns;
    my @curr_ns_feats = ();
    my $has_empty_ns = 0;
    foreach my $feat (@$feats) {
        #print STDERR $feat->[0]."\n";
        if ($feat->[0] =~ /^\|/) {
                #print STDERR Dumper(\@curr_ns_feats);
                if (@curr_ns_feats) {
                    if ($curr_ns) {
                        push @filt_feats, [$curr_ns, undef];
                    }
                    push @filt_feats, @curr_ns_feats;
                    @curr_ns_feats = ();
                }
                $curr_ns = $feat->[0];
        }
        elsif ($print xor $hash{$feat->[0]}) {
            push @curr_ns_feats, $feat;
        }
    }
    if (@curr_ns_feats) {
        if ($curr_ns) {
            push @filt_feats, [$curr_ns, undef];
        }
        push @filt_feats, @curr_ns_feats;
    }
    next if (!@filt_feats);
    
    my $str = Treex::Tool::ML::VowpalWabbit::Util::format_singleline(\@filt_feats, @rest);
    print $str;
}
