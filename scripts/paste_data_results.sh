#!/bin/bash

tmp_dir=/COMP.TMP/paste_data_results.$$
mkdir $tmp_dir

gzipped_data=$1
results=$2

zcat $gzipped_data | cut -f1 --complement > $tmp_dir/data
cat $results | perl -e 'my $p = 1; while (<>) { chomp $_; if ($p) {print "__SHARED__\n$_\n"; $p = 0;} else {print  "$_\n";} if ($_ =~ /^\s*$/) {$p = 1;} }' > $tmp_dir/results
paste $tmp_dir/results $tmp_dir/data

rm -rf $tmp_dir
