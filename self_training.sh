#!/bin/bash

function self_training() {

    $ML_FRAMEWORK_DIR/log.sh INFO "Starting self-training..."

    run_dir=${params[RUN_DIR]}
    
    iter_count=${params[ITER_COUNT]-"10"}
    unlabeled_split_size=${params[UNLABELED_SPLIT_SIZE]}
    unlabeled_data=${params[UNLABELED_DATA]}
    delible=${params[DELIBLE]}
    train_data=${params[TRAIN_DATA]}

    ######################## Unlabeled data splitting #########################
    
    # check if the unlabeled data is a single file (and should be splitted) or it is multiple files defined by a wildcard
    unlabeled_data=`$ML_FRAMEWORK_DIR/scripts/data_split.sh "$unlabeled_data" "$unlabeled_split_size" $run_dir`
    $ML_FRAMEWORK_DIR/log.sh DEBUG "Unlabeled data stored in: $unlabeled_data"
    
    # count the number of instances (so far only for the ranking-style data)
    $ML_FRAMEWORK_DIR/log.sh INFO "Counting the number of instances in UNLABELED_DATA. This might take a few minutes..."
    unlabeled_base=`basename "$unlabeled_data"`
    for file in $unlabeled_data; do
        zcat $file | $ML_FRAMEWORK_DIR/scripts/count_ranking_instances.pl >> $run_dir/data/instances_per_part.$unlabeled_base
    done
    

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

        $ML_FRAMEWORK_DIR/semisup_iter.sh -f $config_file \
            TRAIN_DATA=$train_data \
            TESTED_TRAIN_DATA=${params[TRAIN_DATA]} \
            ML_PARAMS="$ml_params" \
            ITER=$i \
            UNLABELED_PART_SIZES=$run_dir/data/instances_per_part.$unlabeled_base \
            RUN_DIR=$run_dir/iter_$iter

            
        if [ -n $delible ]; then
            system_labeled_data=$run_dir/iter_$iter/data/`basename "$unlabeled_data"`
            $ML_FRAMEWORK_DIR/log.sh INFO "Delible; using gold-labeled training data and $system_labeled_data as a training data for the next iteration."
            #init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_000`
            #$ML_FRAMEWORK_DIR/log.sh INFO "Delible; using gold-labeled model $init_model as an initial model for the next iteration."
        else
            if [ -n $prev_iter ]; then
                prev_iter_system_labeled_data=$run_dir/iter_$prev_iter/data/all.system_labeled.table
            fi
            system_labeled_data=$run_dir/iter_$iter/data/all.system_labeled.table 
            zcat $prev_iter_system_labeled_data $run_dir/iter_$iter/data/`basename "$unlabeled_data"` | gzip -c > $system_labeled_data
            $ML_FRAMEWORK_DIR/log.sh INFO "Not delible; using gold-labeled training data and cumulated data in $system_labeled_data as a training data for the next iteration."
            #init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data`
            #$ML_FRAMEWORK_DIR/log.sh INFO "Not delible; using cumulated model $init_model as an initial model for the next iteration."
        fi
        train_data="${params[TRAIN_DATA]} $system_labeled_data"
        #train_data=$run_dir/iter_$iter/data/`basename "$unlabeled_data"`
        ml_params=${params[ML_PARAMS_FOR_UNLABELED]}

        prev_iter=$iter
    done

    # the final iteration - just training and testing
    iter=`printf "%03d" $iter_count`
    mkdir -p $run_dir/iter_$iter
    echo $iter > $run_dir/iter_$iter/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TRAIN_DATA]} ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TEST_DATA]} ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/stats

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
