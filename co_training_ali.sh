#!/bin/bash

function co_training_ali() {

    run_dir=${params[RUN_DIR]}
    
    iter_count=${params[ITER_COUNT]-"10"}
    delible=${params[DELIBLE]-"0"}
    split=${params[SPLIT]-"0"}
    l1_train_data=${params[L1_TRAIN_DATA]}
    l2_train_data=${params[L2_TRAIN_DATA]}
    
    ######################## Unlabeled data splitting #########################
    
    # check if the unlabeled data is a single file (and should be splitted) or it is multiple files defined by a wildcard
    l1_unlabeled_data=`$ML_FRAMEWORK_DIR/scripts/data_split.sh "${params[L1_UNLABELED_DATA]}" ${params[UNLABELED_SPLIT_SIZE]} $run_dir`
    l2_unlabeled_data=`$ML_FRAMEWORK_DIR/scripts/data_split.sh "${params[L2_UNLABELED_DATA]}" ${params[UNLABELED_SPLIT_SIZE]} $run_dir`
    $ML_FRAMEWORK_DIR/log.sh DEBUG "L1_UNLAB_DATA: $l1_unlabeled_data"
    $ML_FRAMEWORK_DIR/log.sh DEBUG "L2_UNLAB_DATA: $l2_unlabeled_data"
    
    l1_unlabeled_base=`basename "$l1_unlabeled_data"`
    l2_unlabeled_base=`basename "$l2_unlabeled_data"`
    
    # count the number of instances (so far only for the ranking-style data)
    $ML_FRAMEWORK_DIR/log.sh INFO "Counting the number of instances in L1_UNLAB_DATA. This might take a few minutes..."
    for file in $l1_unlabeled_data; do
        #$ML_FRAMEWORK_DIR/log.sh DEBUG "Storing $file into: $run_dir/data/instances_per_part.l1.$l1_unlabeled_base"
        zcat $file | $ML_FRAMEWORK_DIR/scripts/count_ranking_instances.pl >> $run_dir/data/instances_per_part.l1.$l1_unlabeled_base
    done
    $ML_FRAMEWORK_DIR/log.sh INFO "Counting the number of instances in L2_UNLAB_DATA. This might take a few minutes..."
    for file in $l2_unlabeled_data; do
        #$ML_FRAMEWORK_DIR/log.sh DEBUG "Storing into: $run_dir/data/instances_per_part.l2.$l2_unlabeled_base"
        zcat $file | $ML_FRAMEWORK_DIR/scripts/count_ranking_instances.pl >> $run_dir/data/instances_per_part.l2.$l2_unlabeled_base
    done
    
    ######################## Self-training iterations ##########################
    
    ml_params=${params[ML_PARAMS]}

    # iterations
    for (( i=0; i<$iter_count; i++ )); do
        iter=`printf "%03d" $i`

        mkdir -p $run_dir/iter_$iter

        l1_iter_run_dir=$run_dir/iter_$iter/l1
        l2_iter_run_dir=$run_dir/iter_$iter/l2

        run_in_parallel \
            "$ML_FRAMEWORK_DIR/semisup_iter.sh -f $config_file \
                TRAIN_DATA=\"$l1_train_data\" \
                TESTED_TRAIN_DATA=${params[L1_TRAIN_DATA]} \
                TEST_DATA=${params[L1_TEST_DATA]} \
                UNLABELED_DATA=$l1_unlabeled_data \
                ML_PARAMS=\"$ml_params\" \
                ITER=$i \
                UNLABELED_PART_SIZES=$run_dir/data/instances_per_part.l1.$l1_unlabeled_base \
                INITIAL_MODEL=$l1_init_model \
                RUN_DIR=$l1_iter_run_dir;
                touch $run_dir/iter_$iter/done.semisup_iter.l1" \
            "semisup_iter.l1.$iter" -30 $run_dir/log 0
        run_in_parallel \
            "$ML_FRAMEWORK_DIR/semisup_iter.sh -f $config_file \
                TRAIN_DATA=\"$l2_train_data\" \
                TESTED_TRAIN_DATA=${params[L2_TRAIN_DATA]} \
                TEST_DATA=${params[L2_TEST_DATA]} \
                UNLABELED_DATA=$l2_unlabeled_data \
                ML_PARAMS=\"$ml_params\" \
                ITER=$i \
                UNLABELED_PART_SIZES=$run_dir/data/instances_per_part.l2.$l2_unlabeled_base \
                INITIAL_MODEL=$l2_init_model \
                RUN_DIR=$l2_iter_run_dir;
                touch $run_dir/iter_$iter/done.semisup_iter.l2" \
            "semisup_iter.l2.$iter" -30 $run_dir/log 0
        wait_for_jobs "$run_dir/iter_$iter/done.semisup_iter.*" 2

        # transfer the labeling via alignment
        l1_labeled_data=$l1_iter_run_dir/data/$l1_unlabeled_base
        l2_labeled_data=$l2_iter_run_dir/data/$l2_unlabeled_base
        transfer_labels_via_align "$l1_unlabeled_data" "$l2_labeled_data" $l1_iter_run_dir
        transfer_labels_via_align "$l2_unlabeled_data" "$l1_labeled_data" $l2_iter_run_dir
        wait_for_jobs "$l1_iter_run_dir/done.aligned.*" `ls $l1_unlabeled_data | wc -l`
        wait_for_jobs "$l2_iter_run_dir/done.aligned.*" `ls $l2_unlabeled_data | wc -l`
        l1_align_labeled_data=$l1_iter_run_dir/data/aligned.$l1_unlabeled_base
        l2_align_labeled_data=$l2_iter_run_dir/data/aligned.$l2_unlabeled_base

        # merging stats
        echo $iter > $run_dir/iter_$iter/stats
        cat $run_dir/iter_$iter/l1/stats >> $run_dir/iter_$iter/stats
        cat $run_dir/iter_$iter/l2/stats >> $run_dir/iter_$iter/stats

        # set params for the next iteration
        if [ -n "$split" -a "$split" -ne 0 ]; then
            l1_system_labeled_data=$l1_align_labeled_data
            l2_system_labeled_data=$l2_align_labeled_data
            $ML_FRAMEWORK_DIR/log.sh INFO "Split; using only the align-transferred data as a training set for the next iteration."
        else
            l1_system_labeled_data="$l1_labeled_data $l1_align_labeled_data"
            l2_system_labeled_data="$l2_labeled_data $l2_align_labeled_data"
            $ML_FRAMEWORK_DIR/log.sh INFO "Not split; using both the labeled and align-transferred data as a training set for the next iteration."
        fi
        
        if [ -n "$delible" -a "$delible" -ne 0 ]; then
            l1_all_system_labeled_data=$l1_system_labeled_data
            l2_all_system_labeled_data=$l2_system_labeled_data
            $ML_FRAMEWORK_DIR/log.sh INFO "Delible; using gold-labeled training data and $l1_all_system_labeled_data (or $l2_all_system_labeled_data) as a training data for the next iteration."
        else
            if [ -n $prev_iter ]; then
                l1_prev_iter_all_system_labeled_data=$run_dir/iter_$prev_iter/l1/data/all.system_labeled.table
                l2_prev_iter_all_system_labeled_data=$run_dir/iter_$prev_iter/l2/data/all.system_labeled.table
            fi
            l1_all_system_labeled_data=$l1_iter_run_dir/data/all.system_labeled.table 
            l2_all_system_labeled_data=$l2_iter_run_dir/data/all.system_labeled.table 
            zcat $l1_prev_iter_all_system_labeled_data $l1_system_labeled_data | gzip -c > $l1_all_system_labeled_data
            zcat $l2_prev_iter_all_system_labeled_data $l2_system_labeled_data | gzip -c > $l2_all_system_labeled_data
            $ML_FRAMEWORK_DIR/log.sh INFO "Not delible; using gold-labeled training data and cumulated data in $l1_all_system_labeled_data (or $l2_all_system_labeled_data) as a training data for the next iteration."
        fi
        
        l1_train_data="${params[L1_TRAIN_DATA]} $l1_all_system_labeled_data"
        l2_train_data="${params[L2_TRAIN_DATA]} $l2_all_system_labeled_data"
        $ML_FRAMEWORK_DIR/log.sh DEBUG "L1 train data: $l1_train_data"
        $ML_FRAMEWORK_DIR/log.sh DEBUG "L2 train data: $l2_train_data"
        
        prev_iter=$iter
    done

    # the final iteration - just training and testing
    iter=`printf "%03d" $iter_count`
    mkdir -p $run_dir/iter_$iter/l1
    mkdir -p $run_dir/iter_$iter/l2
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter/l1 TRAIN_DATA="$l1_train_data" TEST_DATA=${params[L1_TRAIN_DATA]} INITIAL_MODEL=$l1_init_model ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/l1/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter/l1 TRAIN_DATA="$l1_train_data" TEST_DATA=${params[L1_TEST_DATA]} INITIAL_MODEL=$l1_init_model ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/l1/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter/l2 TRAIN_DATA="$l2_train_data" TEST_DATA=${params[L2_TRAIN_DATA]} INITIAL_MODEL=$l2_init_model ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/l2/stats
    make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter/l2 TRAIN_DATA="$l2_train_data" TEST_DATA=${params[L2_TEST_DATA]} INITIAL_MODEL=$l2_init_model ML_PARAMS="$ml_params" >> $run_dir/iter_$iter/l2/stats
    
    # merging stats
    echo $iter > $run_dir/iter_$iter/stats
    cat $run_dir/iter_$iter/l1/stats >> $run_dir/iter_$iter/stats
    cat $run_dir/iter_$iter/l2/stats >> $run_dir/iter_$iter/stats

    ############################ Collecting statistics #########################
    
    echo -en "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    if [ "${params[ML_PARAMS_FOR_UNLABELED]}" != "${params[ML_PARAMS]}" ]; then
        echo "("${params[ML_PARAMS_FOR_UNLABELED]}")" > $run_dir/stats
    else
        echo > $run_dir/stats
    fi
    # a header used for iter results
    echo "ITER" > $run_dir/stats.header
    print_ranking_header "TRAIN_L1" >> $run_dir/stats.header
    print_ranking_header "TEST_L1" >> $run_dir/stats.header
    print_ranking_header "TRAIN_L2" >> $run_dir/stats.header
    print_ranking_header "TEST_L2" >> $run_dir/stats.header
    
    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    paste $run_dir/stats.header $run_dir/iter_*/stats >> $run_dir/stats
    sed -i 's/$/|/' $run_dir/stats
    rm $run_dir/stats.header
}

function transfer_labels_via_align()
{
    local l1_unlabeled_data=$1
    local l2_labeled_data=$2
    local run_dir=$3
   
    # TODO output file + done file
    for file_part in $l1_unlabeled_data; do
        base=`basename $file_part`
        
        run_in_parallel \
            "zcat $l2_labeled_data | \
            $ML_FRAMEWORK_DIR/scripts/select_aligned_instance.pl $file_part | \
            gzip -c > $run_dir/data/aligned.$base; \
            touch $run_dir/done.aligned.$base" \
        "select_ali.$base" -50 $run_dir/log 0
    done
}
