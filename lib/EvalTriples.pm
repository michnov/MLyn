package EvalTriples;

use strict;
use warnings;

use List::Util qw/max/;

sub acc {
    my ($ok, $all) = @_;
    return $all != 0 ? $ok / $all : 0;
}

sub prf {
    my ($rec_num, $rec_denom, $prec_num, $prec_denom) = @_;
    my $p = $prec_denom != 0 ? $prec_num / $prec_denom : 0;
    my $r = $rec_denom != 0 ? $rec_num / $rec_denom : 0;
    my $f = $p + $r != 0 ? 2 * $p * $r / ($p + $r) : 0;
    return ($p, $r, $f);
}

sub acc_strict {
    my ($true, $pred, $both) = @_;
    return 1 if (($true == 0) && ($pred == 0));
    return 0 if (($true > 0) && ($pred == 0) && ($both != $true));
    return 0 if (($true == 0) && ($pred > 0) && ($both != $pred));
    return 1 if (($true == 0) && ($pred > 0) && ($both == $pred));
    return 1 if (($true > 0) && ($pred == 0) && ($both == $true));
    return 1 if (($true > 0) && ($true == $pred) && ($true == $both));
    return 0;
}

sub acc_lenient {
    my ($true, $pred, $both) = @_;
    return 1 if (($true == 0) && ($pred == $true) && ($both == $true));
    return 1 if ($both > 0);
    return 0;
}

sub acc_weighted {
    my ($true, $pred, $both) = @_;
    my ($p, $r, $f);
    
    return 1 if (($true == 0) && ($pred == 0));
    
    ($p, $r, $f) = prf($both, $true, $both, $true);
    return $f if (($true > 0) && ($pred == 0));
    
    ($p, $r, $f) = prf($both, $pred, $both, $pred);
    return 1 if (($true == 0) && ($pred > 0));
    
    ($p, $r, $f) = prf($both, $true, $both, $pred);
    return $f;
}

sub prf_strict {
    my ($true, $pred, $both) = @_;
    return (0, 0, 0, 0) if (($true == 0) && ($pred == 0));
    return (0, 1, 0, 0) if (($true > 0) && ($pred == 0) && ($both != $true));
    return (0, 0, 0, 1) if (($true == 0) && ($pred > 0) && ($both != $pred));
    return (0, 0, 1, 1) if (($true == 0) && ($pred > 0) && ($both == $pred));
    return (1, 1, 0, 0) if (($true > 0) && ($pred == 0) && ($both == $true));
    return (1, 1, 1, 1) if (($true > 0) && ($true == $pred) && ($true == $both));
    return (0, 1, 0, 1);
}

sub prf_lenient {
    my ($true, $pred, $both) = @_;
    return (0, 0, 0, 0) if (($true == 0) && ($pred == 0));
    return (0, 1, 0, 0) if (($true > 0) && ($pred == 0) && ($both == 0));
    return (0, 0, 0, 1) if (($true == 0) && ($pred > 0) && ($both == 0));
    return (0, 0, 1, 1) if (($true == 0) && ($pred > 0) && ($both > 0));
    return (1, 1, 0, 0) if (($true > 0) && ($pred == 0) && ($both > 0));
    return (0, 1, 0, 1) if (($true > 0) && ($pred > 0) && ($both == 0));
    return (1, 1, 1, 1) if (($true > 0) && ($pred > 0) && ($both > 0));
}

sub prf_weighted {
    my ($true, $pred, $both) = @_;
    return (0, 0, 0, 0) if (($true == 0) && ($pred == 0));
    return (0, 0, $both, $pred) if (($true == 0) && ($pred > 0));
    return ($both, $true, 0, 0) if (($true > 0) && ($pred == 0));
    return ($both, $true, $both, $pred);
}

sub update_acc {
    my ($ok, $acc_counts, $at_ref, $at_src) = @_;
    if ($at_ref || $at_src) {
        $acc_counts->{ok} += $ok;
        $acc_counts->{all} += 1;
    }
}

sub update_prf {
    my ($rec_num, $rec_denom, $prec_num, $prec_denom, $acc_counts, $at_ref, $at_src) = @_;
    if ($at_ref) {
        $acc_counts->{rec_num}    += $rec_num;
        $acc_counts->{rec_denom}  += $rec_denom;
    }
    if ($at_src) {
        $acc_counts->{prec_num}   += $prec_num;
        $acc_counts->{prec_denom} += $prec_denom;
    }
}

sub eval {
    my ($fh, $args) = @_;

    my %acc_strict_counts = ();
    my %acc_lenient_counts = ();
    my %acc_weighted_counts = ();
    my %prf_strict_counts = ();
    my %prf_lenient_counts = ();
    my %prf_weighted_counts = ();

    while (my $line = <$fh>) {
        chomp $line;
        my @score_counts = split / /, $line;

        # the following filters out instances that do not satisfy the "anaphtype" regex
        # anaphtype can be specified in two columns in the result table: starting with "AT_SRC:" or "AT_REF:"
        # they are distinguished in PRF calculation: for P the scorer looks at "AT_SRC:" while it looks at "AT_REF:" for R
        my $at_src = 1;
        my $at_ref = 1;
        if (defined $args->{anaphtype}) {
            my $at = $args->{anaphtype};
            my ($at_src_col) = grep {$_ =~ /^AT_SRC:/} @score_counts;
            my ($at_ref_col) = grep {$_ =~ /^AT_REF:/} @score_counts;
            $at_src = ( ($at_src_col // "") =~ /$at/ ) ? 1 : 0;
            $at_ref = ( ($at_ref_col // "") =~ /$at/ ) ? 1 : 0;
        }

        update_acc(acc_strict(@score_counts), \%acc_strict_counts, $at_ref, $at_src);
        update_acc(acc_lenient(@score_counts), \%acc_lenient_counts, $at_ref, $at_src);
        update_acc(acc_weighted(@score_counts), \%acc_weighted_counts, $at_ref, $at_src);
        update_prf(prf_strict(@score_counts), \%prf_strict_counts, $at_ref, $at_src);
        update_prf(prf_lenient(@score_counts), \%prf_lenient_counts, $at_ref, $at_src);
        update_prf(prf_weighted(@score_counts), \%prf_weighted_counts, $at_ref, $at_src);
    }
   
    my %stats = ();
    if ($args->{acc}) {
        if ($args->{strict}) {
            $stats{acc}{strict} = [
                acc($acc_strict_counts{ok}, $acc_strict_counts{all}),
                $acc_strict_counts{ok},
                $acc_strict_counts{all},
            ];
        }
        if ($args->{lenient}) {
            $stats{acc}{lenient} = [
                acc($acc_lenient_counts{ok}, $acc_lenient_counts{all}),
                $acc_lenient_counts{ok},
                $acc_lenient_counts{all},
            ];
        }
        if ($args->{weighted}) {
            $stats{acc}{weighted} = [
                acc($acc_weighted_counts{ok}, $acc_weighted_counts{all}),
                $acc_weighted_counts{ok},
                $acc_weighted_counts{all},
            ];
        }
    }
    if ($args->{prf}) {
        if ($args->{strict}) {
            my ($p, $r, $f) = prf($prf_strict_counts{rec_num}, $prf_strict_counts{rec_denom}, $prf_strict_counts{prec_num}, $prf_strict_counts{prec_denom});
            $stats{prf}{strict} = [
                $p, $r, $f,
                $prf_strict_counts{rec_num},
                $prf_strict_counts{rec_denom},
                $prf_strict_counts{prec_num},
                $prf_strict_counts{prec_denom},
            ];
        }
        if ($args->{lenient}) {
            my ($p, $r, $f) = prf($prf_lenient_counts{rec_num}, $prf_lenient_counts{rec_denom}, $prf_lenient_counts{prec_num}, $prf_lenient_counts{prec_denom});
            $stats{prf}{lenient} = [
                $p, $r, $f,
                $prf_lenient_counts{rec_num},
                $prf_lenient_counts{rec_denom},
                $prf_lenient_counts{prec_num},
                $prf_lenient_counts{prec_denom},
            ];
        }
        if ($args->{weighted}) {
            my ($p, $r, $f) = prf($prf_weighted_counts{rec_num}, $prf_weighted_counts{rec_denom}, $prf_weighted_counts{prec_num}, $prf_weighted_counts{prec_denom});
            $stats{prf}{weighted} = [
                $p, $r, $f,
                $prf_weighted_counts{rec_num},
                $prf_weighted_counts{rec_denom},
                $prf_weighted_counts{prec_num},
                $prf_weighted_counts{prec_denom},
            ];
        }
    }
    
    return format_stats(\%stats) if ($args->{format});
    return \%stats;
}

sub _format_perc {
    my ($x) = @_;
    return sprintf("%.2f", $x * 100);
}
sub _format_ratio {
    my ($x, $y) = @_;
    return sprintf("(%d/%d)", $x, $y);
}

sub format_stats {
    my ($stats) = @_;

    my $formatted_stats = {};

    if (defined $stats->{acc}) {
        foreach my $style (keys %{$stats->{acc}}) {
            my ($a, $co, $ca) = @{$stats->{acc}{$style}};
            $formatted_stats->{acc}{$style} = [
                _format_perc($a),
                _format_ratio($co, $ca),
            ];
        }
    }
    if (defined $stats->{prf}) {
        foreach my $style (keys %{$stats->{prf}}) {
            my ($p, $r, $f, $rn, $rd, $pn, $pd) = @{$stats->{prf}{$style}};
            $formatted_stats->{prf}{$style} = [
                _format_perc($p), _format_ratio($pn, $pd),
                _format_perc($r), _format_ratio($rn, $rd),
                _format_perc($f),
            ];
        }
    }
    return $formatted_stats;
}

1;
