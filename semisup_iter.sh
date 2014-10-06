#!/bin/bash

source $ML_FRAMEWORK_DIR/common.sh
source $ML_FRAMEWORK_DIR/params.sh
prepare_run_dir
run_dir=${params[RUN_DIR]}

config_file=$run_dir/config
save_params params $config_file


make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=${params[TESTED_TRAIN_DATA]} >> $run_dir/stats
make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=${params[TEST_DATA]} >> $run_dir/stats
    
max_loss=${params[MAX_LOSS]}

file_i=1
for file_part in ${params[UNLABELED_DATA]}; do
    file_i_str=`printf "%03d" $file_i`
    
    result_file=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval result_path CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=$file_part`
    
    mkdir -p $run_dir/data
    sys_labeled_data=$run_dir/data/`basename $file_part`
    
    run_in_parallel \
        "make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=$file_part; \
            $ML_FRAMEWORK_DIR/log.sh INFO \"Adding system labels to the unlabeled data, if the minimum loss is <= $max_loss: $file_part + $result_file => $sys_labeled_data\"; \
            $ML_FRAMEWORK_DIR/scripts/paste_data_results.sh $file_part $result_file | $ML_FRAMEWORK_DIR/scripts/filter_by_loss.pl $max_loss | $ML_FRAMEWORK_DIR/scripts/discretize_losses.pl | gzip -c > $sys_labeled_data; \
            touch $run_dir/done.$file_i_str" \
        "unlabeled.part.$file_i_str" -50 $run_dir/log 0

    ((file_i++))
done

# wait until all experiments are acomplished
$ML_FRAMEWORK_DIR/log.sh INFO "Waiting for all the experiments to be completed..."
unlabeled_count=`ls ${params[UNLABELED_DATA]} | wc -l`
while [ `ls $run_dir/done.* 2> /dev/null | wc -l` -lt $unlabeled_count ]; do
    $ML_FRAMEWORK_DIR/log.sh DEBUG `ls $run_dir/done.* 2> /dev/null | wc -l` $unlabeled_count
    sleep 10
done
