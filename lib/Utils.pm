package Utils;

sub parse_line {
    my ($line) = @_;
    chomp $line;
    my ($class, $feat_str) = split /\t/, $line;
    my @feats = split / /, $feat_str;
    return (\@feats, $class);
}

1;
