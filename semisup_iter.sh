#!/bin/bash

source $ML_FRAMEWORK_DIR/common.sh
source $ML_FRAMEWORK_DIR/params.sh
prepare_run_dir
run_dir=${params[RUN_DIR]}

config_file=$run_dir/config
save_params params $config_file

pool_size=${params[POOL_SIZE]}
unlabeled_part_sizes=${params[UNLABELED_PART_SIZES]}
iter=${params[ITER]}
selection_metrics_threshold=${params[SELECTION_METRICS_THRESHOLD]}
selection_metrics_type=${params[SELECTION_METRICS_TYPE]}

all_base=`basename "${params[UNLABELED_DATA]}"`
unlabeled_data_unfold=(`echo ${params[UNLABELED_DATA]}`)

# train and test the models
make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=${params[TESTED_TRAIN_DATA]} >> $run_dir/stats
make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=${params[TEST_DATA]} >> $run_dir/stats

# get the indexes to be included in the pool
if [ $pool_size -gt 0 ]; then
    unlabeled_data_size=`cat $unlabeled_part_sizes | paste -sd+ | bc`
    $ML_FRAMEWORK_DIR/scripts/rand_seq.pl $unlabeled_data_size $pool_size $iter > $run_dir/pool.idx
    $ML_FRAMEWORK_DIR/scripts/partition_idx.pl -f $unlabeled_part_sizes < $run_dir/pool.idx > $run_dir/pool.parts.idx
    mkdir -p $run_dir/data.pool
    for (( i=0; i<${#unlabeled_data_unfold[@]}; i++ )); do
        file_part=${unlabeled_data_unfold[$i]}
        cat $run_dir/pool.parts.idx | sed -n $(($i+1))'p' > $run_dir/pool.part_i.idx
        if [ -s $run_dir/pool.part_i.idx ]; then
            base=`basename $file_part`
            zcat $file_part | $ML_FRAMEWORK_DIR/scripts/filter_inst.pl --multiline 1 --in $run_dir/pool.part_i.idx | gzip -c > $run_dir/data.pool/$base
            rm $run_dir/pool.part_i.idx
        fi
    done
    unlabeled_data_unfold=`echo $run_dir/data.pool/$all_base`
fi
    

file_i=1
for file_part in $unlabeled_data_unfold; do
    #file_i_str=`printf "%03d" $file_i`
    base=`basename $file_part`
    
    result_file=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval result_path CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=$file_part`
    
    mkdir -p $run_dir/data
    sys_labeled_data=$run_dir/data/$base
    
    run_in_parallel \
        "make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir TEST_DATA=$file_part; \
            $ML_FRAMEWORK_DIR/log.sh INFO \"Adding system labels to the unlabeled data, if the metrics $selection_metrics_type is <= $selection_metrics_threshold: $file_part + $result_file => $sys_labeled_data\"; \
            zcat $file_part | $ML_FRAMEWORK_DIR/scripts/paste_data_results.sh $result_file | $ML_FRAMEWORK_DIR/scripts/filter_by_loss.pl --threshold $selection_metrics_threshold --metrics $selection_metrics_type | $ML_FRAMEWORK_DIR/scripts/discretize_losses.pl | gzip -c > $sys_labeled_data; \
            touch $run_dir/done.$base" \
        "unlabeled.$base" -50 $run_dir/log 0

    ((file_i++))
done

# wait until all experiments are acomplished
unlabeled_count=`ls $unlabeled_data_unfold | wc -l`
wait_for_jobs "$run_dir/done.$all_base" $unlabeled_count
