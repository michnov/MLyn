#!/bin/bash

function self_training() {
    #source $ML_FRAMEWORK_DIR/common.sh
    #source $ML_FRAMEWORK_DIR/params.sh

    run_dir=${params[RUN_DIR]}
    
    #config_file=$run_dir/config

    ###################################

    iter_count=${params[ITER_COUNT]-"10"}
    max_loss=${params[MAX_LOSS]}
    unlabeled_split_size=${params[UNLABELED_SPLIT_SIZE]}
    unlabeled_data=${params[UNLABELED_DATA]}
    delible=${params[DELIBLE]}
    train_data=${params[TRAIN_DATA]}
    
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

    i=0
    iter=`printf "%03d" $i`
    
    mkdir -p $run_dir/iter_$iter
    echo $iter > $run_dir/iter_$iter/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TEST_DATA=${params[TRAIN_DATA]} >> $run_dir/iter_$iter/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TEST_DATA=${params[TEST_DATA]} >> $run_dir/iter_$iter/stats
    init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter`

    if [ -z "${params[ML_PARAMS_FOR_UNLABELED]}" ]; then
        params[ML_PARAMS_FOR_UNLABELED]=${params[ML_PARAMS]}
    fi

    #train_data_ready=`make -s -f $ML_FRAMEWORK_DIR/makefile.preprocess data_ready_path CONFIG_FILE=$config_file DATA_DIR=$run_dir/data DATA=${params[TRAIN_DATA]}`
    for (( i=1; i<=$iter_count; i++ )); do
        old_iter=$iter
        iter=`printf "%03d" $i`

        file_i=1
        for file_part in $unlabeled_data; do
            file_i_str=`printf "%03d" $file_i`
            
            result_file=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval result_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$old_iter TRAIN_DATA=$train_data TEST_DATA=$file_part`
            sys_labeled_data=$run_dir/iter_$iter/data/`basename $file_part`
            
            run_in_parallel \
                "make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$old_iter TRAIN_DATA=$train_data TEST_DATA=$file_part; \
                    mkdir -p $run_dir/iter_$iter/data; \
                    $ML_FRAMEWORK_DIR/log.sh INFO \"Adding system labels to the unlabeled data, if the minimum loss is <= $max_loss: $file_part + $result_file => $sys_labeled_data\"; \
                    $ML_FRAMEWORK_DIR/scripts/paste_data_results.sh $file_part $result_file | $ML_FRAMEWORK_DIR/scripts/filter_by_loss.pl $max_loss | $ML_FRAMEWORK_DIR/scripts/discretize_losses.pl | gzip -c > $sys_labeled_data; \
                    touch $run_dir/iter_$iter/done.$file_i_str" \
                "unlabeled.part.$file_i_str" -50 $run_dir/iter_$iter/log 0

            echo $sys_labeled_data >> $run_dir/iter_$iter/data.to_merge.list
            ((file_i++))
        done

        # wait until all experiments are acomplished
        $ML_FRAMEWORK_DIR/log.sh INFO "Waiting for all the experiments to be completed..."
        while [ `ls $run_dir/iter_$iter/done.* 2> /dev/null | wc -l` -lt $unlabeled_count ]; do
            $ML_FRAMEWORK_DIR/log.sh DEBUG `ls $run_dir/iter_$iter/done.* 2> /dev/null | wc -l` $unlabeled_count
            sleep 10
        done

        $ML_FRAMEWORK_DIR/log.sh INFO "Merging all newly labeled data..."
        #echo ${params[TRAIN_DATA]} >> $run_dir/iter_$iter/data.to_merge.list
        train_data=$run_dir/iter_$iter/data/`basename "$unlabeled_data"`
        #cat $run_dir/iter_$iter/data.to_merge.list | xargs zcat | gzip -c > $train_data
        $ML_FRAMEWORK_DIR/log.sh DEBUG "TRAIN DATA: $train_data"

        $ML_FRAMEWORK_DIR/log.sh INFO "Training and testing with the initial model: $init_model"
        echo $iter > $run_dir/iter_$iter/stats
        make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TRAIN_DATA]} INITIAL_MODEL=$init_model ML_PARAMS="${params[ML_PARAMS_FOR_UNLABELED]}" >> $run_dir/iter_$iter/stats
        make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TEST_DATA]} INITIAL_MODEL=$init_model ML_PARAMS="${params[ML_PARAMS_FOR_UNLABELED]}" >> $run_dir/iter_$iter/stats

        if [ -z $delible ]; then
            init_model=`make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data`
            $ML_FRAMEWORK_DIR/log.sh INFO "Not delible; using cumulated model $init_model as an initial model for the next iteration."
        else
            $ML_FRAMEWORK_DIR/log.sh INFO "Delible; using gold-labeled model $init_model as an initial model for the next iteration."
        fi
    done

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
    rm $run_dir/stats.header
}
