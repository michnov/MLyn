#!/usr/bin/env perl

use warnings;
use strict;

use Data::Dumper;
use Getopt::Long;
use Treex::Tool::ML::TabSpace::Util;
use Treex::Core::Common;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my @ids = ();
my @cand_ids = ();
GetOptions(
    "inst-id=s{2}" => \@ids,
    "cand-id=s{2}" => \@cand_ids,
);

#print STDERR Dumper(\@ids, \@cand_ids);

my $USAGE = <<USAGE;
Usage: $0 <language1_filtered_instances_labeled> --inst-id <id_name> <align_id_name> --cand-id <id_name> <align_id_name>
    - input: language2 all instances unlabeled
    - output: language2 filtered instances labeled
    - selects from language2_all_instances those, which are aligned with language1_filtered_instances
USAGE

if (@ARGV < 1) {
    print $USAGE;
    exit;
}

my %ids_h = ();

open my $filt_fh, "<:utf8", $ARGV[0];
while ( my $instance = Treex::Tool::ML::TabSpace::Util::parse_multiline($filt_fh, {split_key_val => 1}) ) {
    my ($feats, $losses) = @$instance;
    my ($cands_feats, $shared_feats) = @$feats;
    my %shared_feats_h = map {$_->[0] => $_->[1]} @$shared_feats;
    my $id = $shared_feats_h{$ids[0]};
    my $align_id = $shared_feats_h{$ids[1]};
    if (!defined $align_id) {
        log_info "No feature '" . $ids[1] . "' for an instance " . $id;
        next;
    }
    
    my %cands_align_ids = ();
    my @cands_idx = grep {$losses->[$_] == 0} 0 .. $#$losses;
    my @ok_cands_feats = @$cands_feats[@cands_idx];
    foreach my $ok_cand_feats (@ok_cands_feats) {
        my %cand_feats_h = map {$_->[0] => $_->[1]} @$ok_cand_feats;
        if ($cand_feats_h{__SELF__}) {
            $cands_align_ids{__SELF__} = 1;
            next;
        }
        my $cand_id = $cand_feats_h{$cand_ids[0]};
        my $cand_align_id = $cand_feats_h{$cand_ids[1]};
        if (!defined $cand_align_id) {
            log_info "No feature '" . $cand_ids[1] . "' for a candidate " . $cand_id;
            next;
        }
        $cands_align_ids{$cand_align_id} = 1;
    }
    if (%cands_align_ids) {
        if (defined $ids_h{$align_id}) {
            log_warn "Already processed align_id: " . $align_id;
        }
        #print STDERR "OK: " . $id . "\n";
        $ids_h{$align_id} = \%cands_align_ids;
    }
    else {
        log_info "No aligned positive candidates for an instance " . $id;
    }
}
close $filt_fh;

#print STDERR Dumper(\%ids_h);

while ( my $instance = Treex::Tool::ML::TabSpace::Util::parse_multiline(*STDIN, {split_key_val => 1}) ) {
    my ($feats, $old_losses) = @$instance;
    my ($cands_feats, $shared_feats) = @$feats;
    my %shared_feats_h = map {$_->[0] => $_->[1]} @$shared_feats;
    my $id = $shared_feats_h{$ids[0]};
    my $align_id = $shared_feats_h{$ids[1]};
    if (!defined $ids_h{$id}) {
        next;
    }
    
    my @new_losses = ();
    my $has_positive = 0;
    my %cands_align_ids = ();
    foreach my $cand_feats (@$cands_feats) {
        my %cand_feats_h = map {$_->[0] => $_->[1]} @$cand_feats;
        if ($cand_feats_h{__SELF__}) {
            if ($ids_h{$id}{__SELF__}) {
                push @new_losses, 0;
                $has_positive = 1;
            }
            else {
                push @new_losses, 1;
            }
            next;
        }
        my $cand_id = $cand_feats_h{$cand_ids[0]};
        if (defined $ids_h{$id}{$cand_id}) {
            push @new_losses, 0;
            $has_positive = 1;
        }
        else {
            push @new_losses, 1;
        }
    }
    if ($has_positive) {
        #print STDERR "ALIGN_OK: " . $align_id . "\n";
        print Treex::Tool::ML::TabSpace::Util::format_multiline($feats, \@new_losses);
    }
}
