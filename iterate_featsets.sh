#!/bin/bash

# INPUT:
#   1) RUN_DIR - a directory to store all intermediate files in
#   2) FEATSET_LIST - a path to the list of feature sets to run experiments with
# OUTPUT:
#   RUN_DIR/stats

./log.sh INFO "Running $0..."

source common.sh
source params.sh

config_file=${params[RUN_DIR]}/config

###################################

featset_list=${params[FEATSET_LIST]}
run_dir=${params[RUN_DIR]}

./log.sh DEBUG "Processing the featset list: $featset_list => $run_dir/featset_per_line.list"
cat $featset_list | scripts/read_featset_list.pl > $run_dir/featset_per_line.list

iter=000
# run an experiment for every feature set
cat $run_dir/featset_per_line.list | while read featset; do
    iter=`perl -e 'my $x = shift @ARGV; $x++; printf "%03s", $x;' $iter`
    
    feats=`echo "$featset" | cut -d"#" -f1`
    feats_descr=`echo "$featset" | sed 's/^[^#]*#//' | sed 's/__WS__/ /g'`
    feats_sha=`echo "$feats" | shasum | cut -c 1-10`

    run_subdir=$run_dir/$iter.$feats_sha.featset
    mkdir -p $run_subdir

    # print out an info file
    feats_info_file=$run_subdir/info
    echo -en "FEATS:" >> $feats_info_file
    echo -en "\t$feats_descr" >> $feats_info_file
    echo -en "\t$feats_sha" >> $feats_info_file
    echo -e "\t`echo $feats | sed 's/,/, /g'`" >> $feats_info_file
    
    ./log.sh INFO "Running an experiment no. $iter using the featset with sha $feats_sha"
    ./log.sh DEBUG "Its running directory is: $run_subdir"

    run_in_parallel \
        "./iterate_mlmethods.sh \
            -f $config_file \
            FEAT_LIST=$feats \
            RUN_DIR=$run_subdir; \
         touch $run_subdir/done;" \
        "featset_exper.$feats_sha" -50 $run_subdir/log 30
done

# wait until all experiments are acomplished
./log.sh INFO "Waiting for all the experiments to be completed..."
featset_count=`cat $run_dir/featset_per_line.list | wc -l`
while [ `ls $run_dir/*.featset/done 2> /dev/null | wc -l` -lt $featset_count ]; do
    sleep 10
done

# collect results
stats=$run_dir/stats
./log.sh INFO "Collecting results of the experiments to: $stats"
for run_subdir in $run_dir/*.featset; do
    cat $run_subdir/info >> $stats
    cat $run_subdir/stats >> $stats
done
