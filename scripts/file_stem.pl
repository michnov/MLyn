#!/usr/bin/env perl

use warnings;
use strict;
use File::Spec;
use Getopt::Long;

my $multi_out;
GetOptions(
    "multi-out" => \$multi_out,
);

sub extract_stem {
    my ($path) = @_;
    my ($volume, $dirs, $file_stem) = File::Spec->splitpath($path);

    $file_stem =~ s/\.table$//;
    return $file_stem;
}

if (!@ARGV) {
    print STDERR "Usage: $0 [--multi-out] <path>\n";
    exit;
}

my $filestr = $ARGV[0];
my @files = split / +/, $filestr;

my $file_stem;
if ($multi_out) {
    $file_stem = join " ", map {extract_stem($_)} @files;
}
else {
    my $main_file = $files[0];
    $file_stem = extract_stem($main_file);
    $file_stem =~ s/\*/all/g;
    if (@files > 1) {
        $file_stem .= "_and_more";
    }
}
print "$file_stem\n";
