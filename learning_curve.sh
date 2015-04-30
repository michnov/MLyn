#!/bin/bash

function learning_curve() {

    $ML_FRAMEWORK_DIR/log.sh INFO "Starting calculating a learning curve..."

    run_dir=${params[RUN_DIR]}
    
    train_sample_sizes=${params[TRAIN_SAMPLE_SIZES]}
    train_data=${params[TRAIN_DATA]}
    ml_params=${params[ML_PARAMS]}

    i=0
    for sample_size in $train_sample_sizes; do
        iter=`printf "%03d" $i`
        
        iter_name="$iter"_sample_$sample_size
        mkdir -p $run_dir/$iter_name
        echo $sample_size > $run_dir/$iter_name/stats

        run_in_parallel \
            "$ML_FRAMEWORK_DIR/lc_iter.sh -f $config_file \
                TRAIN_SAMPLE_SIZE=$sample_size \
                RUN_DIR=$run_dir/$iter_name; \
                touch $run_dir/done.$iter_name" \
            "lc_iter.$sample_size" -50 $run_dir/log 0

        ((i++))
    done

    wait_for_jobs "$run_dir/done.*" $i
    
    ############################ Collecting statistics #########################
    
    # a header used for sample results
    echo "TRAIN_SAMPLE" > $run_dir/stats.header
    print_ranking_header "TRAIN" >> $run_dir/stats.header
    print_ranking_header "TEST" >> $run_dir/stats.header
    
    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    paste $run_dir/stats.header $run_dir/*_sample_*/stats >> $run_dir/stats
    sed -i 's/$/|/' $run_dir/stats
    rm $run_dir/stats.header
}
