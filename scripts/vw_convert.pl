#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use Treex::Tool::ML::TabSpace::Util;
use Treex::Tool::ML::VowpalWabbit::Util;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

#my $test;
my $multi = 0;
GetOptions(
#    "test" => \$test,
    "multi|m" => \$multi
);

my ($parser, $formatter);
if ($multi) {
    $parser = \&Treex::Tool::ML::TabSpace::Util::parse_multiline;
    $formatter = \&Treex::Tool::ML::VowpalWabbit::Util::format_multiline;
}
else {
    $parser = \&Treex::Tool::ML::TabSpace::Util::parse_singleline;
    $formatter = \&Treex::Tool::ML::VowpalWabbit::Util::format_singleline;
}
while ( my $instance = $parser->(*STDIN) ) {
    print $formatter->(@$instance);
}

#sub print_multiline {
#    my ($instances, $label_num, $is_test) = @_;
#    
#    foreach my $instance (@$instances) {
#        print "shared |s " . $instance->{feats} . "\n";
#        foreach my $label (1 .. $label_num) {
#            my $loss = $label eq $instance->{class} ? 0 : 1;
#            if ($is_test) {
#                print "$label " . $instance->{class} . "|t $label\n";
#            }
#            else {
#                print "$label:$loss |t $label\n";
#            }
#        }
#        print "\n";
#    }
#}
#
#sub print_singleline {
#    my ($instances, $is_test) = @_;
#    
#    foreach my $instance (@$instances) {
#        my $comment = "";
#        if ($is_test) {
#            $comment = $instance->{class};
#        }
#        print $instance->{class} . " $comment| " . $instance->{feats} . "\n";
#    }
#}
#
#
#
## first run over the data to collect all labels
#
##my %all_cs_lemmas = ();
#my @instances = ();
#
#while (my $line = <STDIN>) {
#    my ($feats, $label) = Treex::Tool::ML::TabSpace::Util::parse_line($line);
#    
#    # empty line
#    if (!defined $feats) {
#        print "\n";
#    }
#
#
#
#
#
#    chomp($line);
#    $line =~ s/:/__COL__/g;
#    $line =~ s/\|/__PIPE__/g;
#    my ($class, $feats) = split /\t/, $line;
#
#    push @instances, {class => $class, feats => $feats };
#
#    #$all_cs_lemmas{$cs_lemma}++;
#}
#
##my @sorted_labels = sort {$a <=> $b} keys %all_cs_lemmas;
#
## second run to convert the data into the VW format
#
#if (defined $multi) {
#    print_multiline(\@instances, $multi, $test);
#} else {
#    print_singleline(\@instances, $test);
#}
