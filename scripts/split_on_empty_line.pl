#!/usr/bin/env perl

use warnings;
use strict;

binmode STDIN, "utf8";

my $usage = "$0 <part_size> <prefix>";

if (@ARGV < 2) {
    die $usage;
}

my $part_size = $ARGV[0];
my $file_prefix = $ARGV[1];

my $out_part_file;
my $part_id = 1;

my $filename = sprintf "%s_%.3d.table", $file_prefix, $part_id;
open $out_part_file, ">:gzip:utf8", $filename or die "Cannot open $filename";
print STDERR "Printing into $filename\n";

my $i = 0;
while (my $line = <STDIN>) {
    
    print $out_part_file "$line";
    $i++;
    if (($i >= $part_size) && ($line =~ /^\s*$/)) {
        close $out_part_file;
        $part_id++;
        $filename = sprintf "%s_%.3d.table", $file_prefix, $part_id;
        open $out_part_file, ">:gzip:utf8", $filename  or die "Cannot open $filename";
        print STDERR "Printing into $filename\n";
        $i = 0;
    }
}
close $out_part_file;
