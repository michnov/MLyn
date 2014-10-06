#!/bin/bash

function co_training_ali() {

    run_dir=${params[RUN_DIR]}
    
    iter_count=${params[ITER_COUNT]-"10"}
    delible=${params[DELIBLE]}
    l1_train_data=${params[L1_TRAIN_DATA]}
    l2_train_data=${params[L2_TRAIN_DATA]}
    
    ######################## Unlabeled data splitting #########################
    
    # check if the unlabeled data is a single file (and should be splitted) or it is multiple files defined by a wildcard
    l1_unlabeled_data=`$ML_FRAMEWORK_DIR/scripts/data_split.sh "${params[L1_UNLABELED_DATA]}" ${params[UNLABELED_SPLIT_SIZE]} $run_dir`
    l2_unlabeled_data=`$ML_FRAMEWORK_DIR/scripts/data_split.sh "${params[L2_UNLABELED_DATA]}" ${params[UNLABELED_SPLIT_SIZE]} $run_dir`
    $ML_FRAMEWORK_DIR/log.sh DEBUG "L1_UNLAB_DATA: $l1_unlabeled_data"
    $ML_FRAMEWORK_DIR/log.sh DEBUG "L2_UNLAB_DATA: $l2_unlabeled_data"
    
    ######################## Self-training iterations ##########################
    
    # different settings of ML_PARAMS for the 0th and next iterations
    if [ -z "${params[ML_PARAMS_FOR_UNLABELED]}" ]; then
        params[ML_PARAMS_FOR_UNLABELED]=${params[ML_PARAMS]}
    fi
    ml_params=${params[ML_PARAMS]}

    # iterations
    for (( i=0; i<$iter_count; i++ )); do
        iter=`printf "%03d" $i`

        mkdir -p $run_dir/iter_$iter
        echo $iter > $run_dir/iter_$iter/stats

        l1_iter_run_dir=$run_dir/iter_$iter/l1
        l2_iter_run_dir=$run_dir/iter_$iter/l2

        run_in_parallel \
            "$ML_FRAMEWORK_DIR/semisup_iter.sh -f $config_file \
                TRAIN_DATA=$l1_train_data \
                TESTED_TRAIN_DATA=${params[L1_TRAIN_DATA]} \
                TEST_DATA=${params[L1_TEST_DATA]} \
                UNLABELED_DATA=$l1_unlabeled_data \
                ML_PARAMS=\"$ml_params\" \
                INITIAL_MODEL=$l1_init_model \
                RUN_DIR=$run_dir/iter_$iter/l1;
                touch $run_dir/iter_$iter/done.semisup_iter.l1" \
            "semisup_iter.l1.$iter" -30 $run_dir/log 0
        
        run_in_parallel \
            "$ML_FRAMEWORK_DIR/semisup_iter.sh -f $config_file \
                TRAIN_DATA=$l2_train_data \
                TESTED_TRAIN_DATA=${params[L2_TRAIN_DATA]} \
                TEST_DATA=${params[L2_TEST_DATA]} \
                UNLABELED_DATA=$l2_unlabeled_data \
                ML_PARAMS=\"$ml_params\" \
                INITIAL_MODEL=$l2_init_model \
                RUN_DIR=$run_dir/iter_$iter/l2;
                touch $run_dir/iter_$iter/done.semisup_iter.l2" \
            "semisup_iter.l2.$iter" -30 $run_dir/log 0

        # wait until both experiments are acomplished
        $ML_FRAMEWORK_DIR/log.sh INFO "Waiting for both experiments to be completed..."
        while [ `ls $run_dir/iter_$iter/done.semisup_iter.* 2> /dev/null | wc -l` -lt 2 ]; do
            $ML_FRAMEWORK_DIR/log.sh DEBUG `ls $run_dir/iter_$iter/done.semisup_iter.* 2> /dev/null | wc -l` 2
            sleep 10
        done

            
        if [ -z $delible ]; then
            l1_init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter/l1 TRAIN_DATA=$l1_train_data`
            l2_init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter/l2 TRAIN_DATA=$l2_train_data`
            $ML_FRAMEWORK_DIR/log.sh INFO "Not delible; using cumulated models $l1_init_model and $l2_init_model as initial models for the next iteration."
        else
            l1_init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_000/l1 TRAIN_DATA=${params[L1_TRAIN_DATA]}`
            l2_init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_000/l2 TRAIN_DATA=${params[L2_TRAIN_DATA]}`
            $ML_FRAMEWORK_DIR/log.sh INFO "Delible; using gold-labeled models $l1_init_model and $l2_init_model as initial models for the next iteration."
        fi
        l1_train_data=$run_dir/iter_$iter/l1/data/`basename "$l1_unlabeled_data"`
        l2_train_data=$run_dir/iter_$iter/l2/data/`basename "$l2_unlabeled_data"`
        ml_params=${params[ML_PARAMS_FOR_UNLABELED]}
    done

    # the final iteration - just training and testing
    iter=`printf "%03d" $iter_count`
    mkdir -p $run_dir/iter_$iter
    echo $iter > $run_dir/iter_$iter/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TRAIN_DATA]} INITIAL_MODEL=$init_model ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TEST_DATA]} INITIAL_MODEL=$init_model ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/stats

    ############################ Collecting statistics #########################
    
    echo -en "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    if [ "${params[ML_PARAMS_FOR_UNLABELED]}" != "${params[ML_PARAMS]}" ]; then
        echo "("${params[ML_PARAMS_FOR_UNLABELED]}")" > $run_dir/stats
    else
        echo > $run_dir/stats
    fi
    # a header used for iter results
    echo "ITER" > $run_dir/stats.header
    print_ranking_header "TRAIN" >> $run_dir/stats.header
    print_ranking_header "TEST" >> $run_dir/stats.header
    
    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    paste $run_dir/stats.header $run_dir/iter_*/stats >> $run_dir/stats
    sed -i 's/$/|/' $run_dir/stats
    rm $run_dir/stats.header
}
