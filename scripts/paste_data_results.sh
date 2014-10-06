#!/bin/bash

tmp_dir=/COMP.TMP/paste_data_results.$$
mkdir $tmp_dir

gzipped_data=$1
results=$2

cat $results | cut -f1 -d' ' | perl -e '$ni = 1; while (<STDIN>) { chomp $_; if ($ni) { print "\n"; } if ($_ =~ /^$/) {$ni = 1;} else {$ni = 0;}; print "$_\n"; }' > $tmp_dir/results
zcat $gzipped_data | paste -d '|' $tmp_dir/results - > $tmp_dir/data
cat $tmp_dir/data | perl -ne 'chomp $_; my ($new_value, $x, @rest) = split /\|/, $_; if ($new_value =~ /^$/) {print join "|", ($x, @rest); print "\n";} else { my ($label, $tag) = split / /, $x; my ($idx, $value) = split /:/, $label; print join "|", ($idx.":".$new_value." ".$tag, @rest); print "\n";}'

rm -rf $tmp_dir
