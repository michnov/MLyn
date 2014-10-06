#!/bin/bash

tmp_dir=/COMP.TMP/paste_data_results.$$
mkdir $tmp_dir

gzipped_data=$1
results=$2

zcat $gzipped_data > $tmp_dir/data
cat $results | cut -f1 -d' ' | perl -e '$ni = 1; while (<STDIN>) { chomp $_; if ($ni) { print "\n"; } if ($_ =~ /^$/) {$ni = 1;} else {$ni = 0;}; print "$_\n"; }' > $tmp_dir/results
zcat $gzipped_data | paste $tmp_dir/results - | perl -ne 'chomp $_; my ($res, $x, @rest) = split /\t/, $_; if ($res =~ /^$/) {print join "\t", ($x, @rest); print "\n";} else { ($first, $second, @parts) = split /:/, $x; print join "\t", (join ":", $first.":".$res.$second, @parts), @rest; print "\n";}'

rm -rf $tmp_dir
