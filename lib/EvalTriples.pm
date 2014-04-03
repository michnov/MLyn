package EvalTriples;

use strict;
use warnings;

use List::Util qw/max/;

sub acc {
    my ($ok, $all) = @_;
    return $all != 0 ? $ok / $all : 0;
}

sub prf {
    my ($true, $pred, $both) = @_;
    my $p = $pred != 0 ? $both / $pred : 0;
    my $r = $true != 0 ? $both / $true : 0;
    my $f = $p + $r != 0 ? 2 * $p * $r / ($p + $r) : 0;
    return ($p, $r, $f);
}

sub acc_strict {
    my ($true, $pred, $both) = @_;
    return 1 if (($true == $pred) && ($true == $both));
    return 0;
}

sub acc_lenient {
    my ($true, $pred, $both) = @_;
    return 1 if ($both > 0);
    return 1 if (($true == $pred) && ($true == 0));
    return 0;
}

sub acc_weighted {
    my ($true, $pred, $both) = @_;
    return 1 if (($true == $pred) && ($true == $both));
    my ($p, $r, $f) = prf($true, $pred, $both);
    return $f;
}

sub prf_strict {
    my ($true, $pred, $both) = @_;
    if (($true == $pred) && ($true == $both)) {
        return (1, 1, 1) if ($true > 0);
        return (0, 0, 0);
    }
    return (map {$_ > 0} ($true, $pred), 0);
    #if ($true == 0) {
    #    return (0, 1, 0);
    #}
    #return (1, 0, 0);
}

sub prf_lenient {
    my ($true, $pred, $both) = @_;
    return (1, 1, 1) if ($both > 0);
    return (map {$_ > 0} ($true, $pred), 0);
}

sub prf_weighted {
    my ($true, $pred, $both) = @_;
    return ($true, $pred, $both);
}

sub update_acc {
    my ($ok, $acc_counts) = @_;
    $acc_counts->{ok} += $ok;
    $acc_counts->{all} += 1;
}

sub update_prf {
    my ($true, $pred, $both, $acc_counts) = @_;
    $acc_counts->{true} += $true;
    $acc_counts->{pred} += $pred;
    $acc_counts->{both} += $both;
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
            my ($p, $r, $f) = prf($prf_strict_counts{true}, $prf_strict_counts{pred}, $prf_strict_counts{both});
            $stats{prf}{strict} = [
                $p, $r, $f,
                $prf_strict_counts{true},
                $prf_strict_counts{pred},
                $prf_strict_counts{both},
            ];
        }
        if ($args->{lenient}) {
            my ($p, $r, $f) = prf($prf_lenient_counts{true}, $prf_lenient_counts{pred}, $prf_lenient_counts{both});
            $stats{prf}{lenient} = [
                $p, $r, $f,
                $prf_lenient_counts{true},
                $prf_lenient_counts{pred},
                $prf_lenient_counts{both},
            ];
        }
        if ($args->{weighted}) {
            my ($p, $r, $f) = prf($prf_weighted_counts{true}, $prf_weighted_counts{pred}, $prf_weighted_counts{both});
            $stats{prf}{weighted} = [
                $p, $r, $f,
                $prf_weighted_counts{true},
                $prf_weighted_counts{pred},
                $prf_weighted_counts{both},
            ];
        }
    }
    
    return format_stats(\%stats) if ($args->{format});
    return \%stats;
}

sub _format_perc {
    my ($x) = @_;
    return sprintf("%.2f%%", $x * 100);
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
            my ($p, $r, $f, $ct, $cp, $cb) = @{$stats->{prf}{$style}};
            $formatted_stats->{prf}{$style} = [
                _format_perc($p), _format_ratio($cb, $cp),
                _format_perc($r), _format_ratio($cb, $ct),
                _format_perc($f),
            ];
        }
    }
    return $formatted_stats;
}

1;
