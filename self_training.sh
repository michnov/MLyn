#!/bin/bash

function self_training() {

    run_dir=${params[RUN_DIR]}
    
    iter_count=${params[ITER_COUNT]-"10"}
    unlabeled_split_size=${params[UNLABELED_SPLIT_SIZE]}
    unlabeled_data=${params[UNLABELED_DATA]}
    delible=${params[DELIBLE]}
    train_data=${params[TRAIN_DATA]}
    
    ######################## Unlabeled data splitting #########################
    
    # check if the unlabeled data is a single file (and should be splitted) or it is multiple files defined by a wildcard
    unlabeled_count=`ls $unlabeled_data | wc -l`
    if [ $unlabeled_count -eq 1 ]; then
        if [ ! -z $unlabeled_split_size ]; then
            $ML_FRAMEWORK_DIR/log.sh DEBUG "UNLABELED SPLIT SIZE = $unlabeled_split_size"
            file_stem=`make -s -f $ML_FRAMEWORK_DIR/makefile.common file_stem FILE=$unlabeled_data`
            zcat $unlabeled_data | $ML_FRAMEWORK_DIR/scripts/split_on_empty_line.pl $unlabeled_split_size $run_dir/data/$data_stem.part
            unlabeled_data=$run_dir/data/$data_stem.part*
        fi
    elif [ $unlabeled_count -eq 0 ]; then
        $ML_FRAMEWORK_DIR/log.sh ERROR "UNLABELED_DATA must be defined."
        exit 1
    fi
    $ML_FRAMEWORK_DIR/log.sh DEBUG "Unlabeled data stored in: $unlabeled_data"
        
    
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
            INITIAL_MODEL=$init_model \
            RUN_DIR=$run_dir/iter_$iter

            
        if [ -z $delible ]; then
            init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data`
            $ML_FRAMEWORK_DIR/log.sh INFO "Not delible; using cumulated model $init_model as an initial model for the next iteration."
        else
            init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_000`
            $ML_FRAMEWORK_DIR/log.sh INFO "Delible; using gold-labeled model $init_model as an initial model for the next iteration."
        fi
        train_data=$run_dir/iter_$iter/data/`basename "$unlabeled_data"`
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
