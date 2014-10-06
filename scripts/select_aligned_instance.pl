#!/usr/bin/env perl

use warnings;
use strict;

use Data::Dumper;
use Getopt::Long;
use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Core::Common;

my $DEFAULT_LOSS = 1;

sub parse_cmt {
    my ($cmt) = @_;
    return split / /, $cmt;
}

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

#my @ids = ();
#my @cand_ids = ();
#GetOptions(
#    "inst-id=s{2}" => \@ids,
#    "cand-id=s{2}" => \@cand_ids,
#);

#print STDERR Dumper(\@ids, \@cand_ids);

my $USAGE = <<USAGE;
Usage: $0 <language2_all_instances_unlabeled> --inst-id <id_name> <align_id_name> --cand-id <id_name> <align_id_name>
    - input: language1 filtered instances labeled
    - output: language2 filtered instances labeled
    - selects from language2_all_instances those, which are aligned with language1_filtered_instances
USAGE

if (@ARGV < 1) {
    print $USAGE;
    exit;
}

my %ids_h = ();

while ( my ($feats, $losses, $tag, $comment) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN, {parse_feats => 'no'}) ) {
    my ($cand_cmt, $shared_cmt) = @$comment;
    my ($inst_id, $inst_ali_id) = parse_cmt($shared_cmt);
    #print "ID: $inst_id" . "\n";
    if (!defined $inst_ali_id) {
        #log_info "No counterpart for an instance: " . $inst_id;
        next;
    }
    
    my %cands_align_ids = ();
    for (my $i = 0; $i < @$cand_cmt; $i++) {
        my ($cand_id, $cand_ali_id) = parse_cmt($cand_cmt->[$i]);
        
        # __SELF__ candidate
        if (!$cand_id) {
            $cands_align_ids{__SELF__} = $losses->[$i];
            next;
        }
        if (!defined $cand_ali_id) {
            #log_info "No counterpart for a candidate: " . $cand_id;
            next;
        }
        $cands_align_ids{$cand_ali_id} = $losses->[$i];
    }
    if (%cands_align_ids) {
        if (defined $ids_h{$inst_ali_id}) {
            #log_warn "Already processed align_id: " . $inst_ali_id;
        }
        #print STDERR "OK: " . $id . "\n";
        $ids_h{$inst_ali_id} = \%cands_align_ids;
    }
    else {
        log_info "No aligned candidates for an instance " . $inst_id;
    }

#    my ($cands_feats, $shared_feats) = @$feats;
#    my %shared_feats_h = map {$_->[0] => $_->[1]} @$shared_feats;
#    my $id = $shared_feats_h{$ids[0]};
#    my $align_id = $shared_feats_h{$ids[1]};
#    
#    my %cands_align_ids = ();
#    my @cands_idx = grep {$losses->[$_] == 0} 0 .. $#$losses;
#    my @ok_cands_feats = @$cands_feats[@cands_idx];
#    foreach my $ok_cand_feats (@ok_cands_feats) {
#        my %cand_feats_h = map {$_->[0] => $_->[1]} @$ok_cand_feats;
#        if ($cand_feats_h{__SELF__}) {
#            $cands_align_ids{__SELF__} = 1;
#            next;
#        }
#        my $cand_id = $cand_feats_h{$cand_ids[0]};
#        my $cand_align_id = $cand_feats_h{$cand_ids[1]};
#        if (!defined $cand_align_id) {
#            log_info "No feature '" . $cand_ids[1] . "' for a candidate " . $cand_id;
#            next;
#        }
#        $cands_align_ids{$cand_align_id} = 1;
#    }
#    if (%cands_align_ids) {
#        if (defined $ids_h{$align_id}) {
#            log_warn "Already processed align_id: " . $align_id;
#        }
#        #print STDERR "OK: " . $id . "\n";
#        $ids_h{$align_id} = \%cands_align_ids;
#    }
#    else {
#        log_info "No aligned positive candidates for an instance " . $id;
#    }
}

#print STDERR Dumper(\%ids_h);

open my $filt_fh, "<:gzip:utf8", $ARGV[0];
while ( my ($feats, $old_losses, $tag, $comment) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline($filt_fh, {parse_feats => 'no'}) ) {
    my ($cand_cmt, $shared_cmt) = @$comment;
    my ($inst_id, $inst_ali_id) = parse_cmt($shared_cmt);
    if (!defined $ids_h{$inst_id}) {
        next;
    }
    
    my @new_losses = ();
    my $cand_h = $ids_h{$inst_id};
    for (my $i = 0; $i < @$cand_cmt; $i++) {
        my ($cand_id, $cand_ali_id) = parse_cmt($cand_cmt->[$i]);
        
        # __SELF__ candidate
        if (!defined $cand_id) {
            push @new_losses, $cand_h->{__SELF__};
            next;
        }
        if (defined $cand_h->{$cand_id}) {
            push @new_losses, $cand_h->{$cand_id};
        }
        else {
            push @new_losses, $DEFAULT_LOSS;
        }
    }
    # only if discretized losses
    if (any {$_ == 0} @new_losses) {
        print Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, \@new_losses, $comment);
    }
    else {
        log_info "No positive candidates in the instance: " . $inst_id;
    }
     
    
#    my ($cands_feats, $shared_feats) = @$feats;
#    my %shared_feats_h = map {$_->[0] => $_->[1]} @$shared_feats;
#    my $id = $shared_feats_h{$ids[0]};
#    my $align_id = $shared_feats_h{$ids[1]};
#    
#    my @new_losses = ();
#    my $has_positive = 0;
#    my %cands_align_ids = ();
#    foreach my $cand_feats (@$cands_feats) {
#        my %cand_feats_h = map {$_->[0] => $_->[1]} @$cand_feats;
#        if ($cand_feats_h{__SELF__}) {
#            if ($ids_h{$id}{__SELF__}) {
#                push @new_losses, 0;
#                $has_positive = 1;
#            }
#            else {
#                push @new_losses, 1;
#            }
#            next;
#        }
#        my $cand_id = $cand_feats_h{$cand_ids[0]};
#        if (defined $ids_h{$id}{$cand_id}) {
#            push @new_losses, 0;
#            $has_positive = 1;
#        }
#        else {
#            push @new_losses, 1;
#        }
#    }
#    if ($has_positive) {
#        #print STDERR "ALIGN_OK: " . $align_id . "\n";
#        print Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, \@new_losses);
#    }
}
close $filt_fh;
