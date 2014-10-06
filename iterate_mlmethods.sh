#!/bin/bash

source common.sh

declare -A params
load_params params "$@"
config_file=${params[RUN_DIR]}/config
save_params params $config_file

###################################

featset=${params[FEATSET]}
mlmethod_list=${params[MLMETHOD_LIST]}
run_dir=${params[RUN_DIR]}

result_template=conf/result.template

iter=000
cat $mlmethod_list | grep -v "^#" > $run_dir/mlmethod_per_line.list
if [ ${params[RANKING]}. == 1. ]; then
    cat $run_dir/mlmethod_per_line.list | grep "ranking" > $run_dir/mlmethod_per_line.list.tmp
    cp $run_dir/mlmethod_per_line.list.tmp $run_dir/mlmethod_per_line.list
    result_template=conf/result.ranking.template
fi

# run an experiment for every feature set
cat $run_dir/mlmethod_per_line.list | while read ml_method_info; do
    iter=`perl -e 'my $x = shift @ARGV; $x++; printf "%03s", $x;' $iter`
    
    ml_method=`echo $ml_method_info | cut -f1 -d':'`
    ml_params="`echo $ml_method_info | cut -f2- -d':'`"
    ml_method_sha=`echo "$ml_method_info" | shasum | cut -c 1-5`

    run_subdir=$run_dir/$iter.$ml_method_sha.mlmethod
    mkdir -p $run_subdir

    # print a header into a subprocess stats file
    echo $ml_method $ml_params >> $run_subdir/stats

    run_in_parallel \
        "echo ahoj" \
        "mlmethod_exper.$ml_method_sha" -20 $run_subdir/log 2
        
        # TODO
        #"make -s tte SEMI_SUP=$(SEMI_SUP) DATA_SOURCE_1=$(DATA_SOURCE_1) DATA_SOURCE_2=$(DATA_SOURCE_2) DATA_DIR_1=$(DATA_DIR_1) DATA_DIR_2=$(DATA_DIR_2) RANKING=$(RANKING) CROSS_VALID_N=$(CROSS_VALID_N) TRAIN_DATA_NAME=$(TRAIN_DATA_NAME) TEST_DATA_NAME=$(TEST_DATA_NAME) DATA_SOURCE=$(DATA_SOURCE) STATS_FILE=$(TTE_FEATS_DIR)/acc.$$iter.$$featsha DATA_DIR=$(DATA_DIR) TTE_DIR=$(TTE_FEATS_DIR)/$$featsha FEAT_LIST=$$feat_list FEAT_DESCR=\"$$feat_descr\"; \
        #touch $(TTE_FEATS_DIR)/done.$$featsha;";
done

# wait until all experiments are acomplished
mlmethods_count=`cat $run_dir/mlmethod_per_line.list | wc -l`
while [ `ls $run_dir/*.mlmethod/done 2> /dev/null | wc -l` -lt $mlmethods_count ]; do
    sleep 5
done

# collect results
paste $result_template $run_dir/*.mlmethod/stats >> $run_dir/stats
