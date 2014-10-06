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
Usage: $0 <language2_all_instances_unlabeled>
    - input: language1 filtered instances labeled
    - output: language2 filtered instances labeled
    - selects from language2_all_instances those, which are aligned with language1_filtered_instances
    - counterparts are identified using the ids in comments
USAGE

if (@ARGV < 1) {
    print $USAGE;
    exit;
}

my %ids_h = ();

my $inst_num = 0;
while ( my ($feats, $losses, $tag, $comment) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline(*STDIN, {parse_feats => 'no'}) ) {

    if ($inst_num % 10000 == 0) {
        log_info "Loaded instances: $inst_num";
    }
    $inst_num++;

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

}

#print STDERR Dumper(\%ids_h);

$inst_num = 0;
my $selected_num = 0;

open my $filt_fh, "<:gzip:utf8", $ARGV[0];
while ( my ($feats, $old_losses, $tag, $comment) = Treex::Tool::ML::VowpalWabbit::Util::parse_multiline($filt_fh, {parse_feats => 'no'}) ) {
    
    if ($inst_num % 10000 == 0) {
        log_info "Instances selected and processed: $selected_num / $inst_num";
    }
    $inst_num++;
    
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
        $selected_num++;
    }
    else {
        #log_info "No positive candidates in the instance: " . $inst_id;
    }
}
close $filt_fh;
