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
    my ($ok, $acc_counts) = @_;
    $acc_counts->{ok} += $ok;
    $acc_counts->{all} += 1;
}

sub update_prf {
    my ($rec_num, $rec_denom, $prec_num, $prec_denom, $acc_counts) = @_;
    $acc_counts->{rec_num}    += $rec_num;
    $acc_counts->{rec_denom}  += $rec_denom;
    $acc_counts->{prec_num}   += $prec_num;
    $acc_counts->{prec_denom} += $prec_denom;
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

        update_acc(acc_strict(@score_counts), \%acc_strict_counts);
        update_acc(acc_lenient(@score_counts), \%acc_lenient_counts);
        update_acc(acc_weighted(@score_counts), \%acc_weighted_counts);
        update_prf(prf_strict(@score_counts), \%prf_strict_counts);
        update_prf(prf_lenient(@score_counts), \%prf_lenient_counts);
        update_prf(prf_weighted(@score_counts), \%prf_weighted_counts);
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
