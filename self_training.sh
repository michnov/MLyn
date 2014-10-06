#!/bin/bash


function self_training() {
    #source common.sh
    #source params.sh

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
        ./log.sh DEBUG "UNLABELED SPLIT SIZE = $unlabeled_split_size"
            data_stem=`make -s -f makefile.preprocess data_stem DATA=${params[UNLABELED_DATA]}`
            zcat $unlabeled_data | scripts/split_on_empty_line.pl $unlabeled_split_size $run_dir/data/$data_stem.part
            unlabeled_data=$run_dir/data/$data_stem.part*
        fi
    elif [ $unlabeled_count -eq 0 ]; then
        ./log.sh ERROR "UNLABELED_DATA must be defined."
        exit 1
    fi
    ./log.sh DEBUG "Unlabeled data stored in: $unlabeled_data"

    i=0
    iter=`printf "%03d" $i`
    
    echo $iter > $run_dir/iter_$iter/stats
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TEST_DATA=${params[TRAIN_DATA]} > >(tee -a $run_dir/iter_$iter/stats)
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TEST_DATA=${params[TEST_DATA]} > >(tee -a $run_dir/iter_$iter/stats)
    init_model=`make -s -f makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter`

    if [ ! -z ${params[ML_PARAMS_FOR_UNLABELED]} ]; then
        params[ML_PARAMS_FOR_UNLABELED]=${params[ML_PARAMS]}
    fi

    #train_data_ready=`make -s -f makefile.preprocess data_ready_path CONFIG_FILE=$config_file DATA_DIR=$run_dir/data DATA=${params[TRAIN_DATA]}`
    for (( i=1; i<=$iter_count; i++ )); do
        old_iter=$iter
        iter=`printf "%03d" $i`

        file_i=1
        for file_part in $unlabeled_data; do
            file_i_str=`printf "%03d" $file_i`
            
            result_file=`make -s -f makefile.train_test_eval result_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$old_iter TRAIN_DATA=$train_data TEST_DATA=$file_part`
            sys_labeled_data=$run_dir/iter_$iter/data/`basename $file_part`
            
            run_in_parallel \
                "make -s -f makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$old_iter TRAIN_DATA=$train_data TEST_DATA=$file_part; \
                    mkdir -p $run_dir/iter_$iter/data; \
                    ./log.sh INFO \"Adding system labels to the unlabeled data, if the minimum loss is <= $max_loss: $file_part + $result_file => $sys_labeled_data\"; \
                    scripts/paste_data_results.sh $file_part $result_file | scripts/filter_by_loss.pl $max_loss | scripts/discretize_losses.pl | gzip -c > $sys_labeled_data; \
                    touch $run_dir/iter_$iter/done.$file_i_str" \
                "unlabeled.part.$file_i_str" -50 $run_dir/iter_$iter/log 0

            echo $sys_labeled_data >> $run_dir/iter_$iter/data.to_merge.list
            ((file_i++))
        done

        # wait until all experiments are acomplished
        ./log.sh INFO "Waiting for all the experiments to be completed..."
        while [ `ls $run_dir/iter_$iter/done.* 2> /dev/null | wc -l` -lt $unlabeled_count ]; do
            ./log.sh DEBUG `ls $run_dir/iter_$iter/done.* 2> /dev/null | wc -l` $unlabeled_count
            sleep 10
        done

        ./log.sh INFO "Merging all newly labeled data..."
        #echo ${params[TRAIN_DATA]} >> $run_dir/iter_$iter/data.to_merge.list
        train_data=$run_dir/iter_$iter/data/`basename "$unlabeled_data"`
        #cat $run_dir/iter_$iter/data.to_merge.list | xargs zcat | gzip -c > $train_data
        ./log.sh DEBUG "TRAIN DATA: $train_data"

        ./log.sh INFO "Training and testing with the initial model: $init_model"
        echo $iter > $run_dir/iter_$iter/stats
        make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TRAIN_DATA]} INITIAL_MODEL=$init_model ML_PARAMS=${params[ML_PARAMS_FOR_UNLABELED]} > >(tee -a $run_dir/iter_$iter/stats)
        make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TEST_DATA]} INITIAL_MODEL=$init_model ML_PARAMS=${params[ML_PARAMS_FOR_UNLABELED]} > >(tee -a $run_dir/iter_$iter/stats)

        if [ ! -z $delible ]; then
            init_model=`make -s -f makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data`
        fi
    done

    paste $run_dir/iter_*/stats > $run_dir/stats
}
