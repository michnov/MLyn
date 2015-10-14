#!/bin/bash

function cross_validation() {

    $ML_FRAMEWORK_DIR/log.sh INFO "Starting cross-validation..."

    run_dir=${params[RUN_DIR]}
    
    cross_valid_n=${params[CROSS_VALID_N]}
    full_data=${params[FULL_DATA]}
    ml_params=${params[ML_PARAMS]}
	
	for (( i=0; i<$cross_valid_n; i++ )); do
        iter=`printf "%02d" $i`
        
        iter_name="$iter"_iter
        mkdir -p $run_dir/$iter_name
        
        run_in_parallel \
            "$ML_FRAMEWORK_DIR/cv_iter.sh -f $config_file \
                CROSS_VALID_N=$cross_valid_n \
                CROSS_VALID_I=$i \
                RUN_DIR=$run_dir/$iter_name; \
                touch $run_dir/done.$iter_name" \
            "cv.$iter_name" -50 $run_dir/log 0
		
	done

    wait_for_jobs "$run_dir/done.*" $i
    
    ############################ Collecting statistics #########################

    # all numbers
    mkdir -p $run_dir/result
    cat $run_dir/*_iter/result/train.data.*.res > $run_dir/result/train.data.res
    cat $run_dir/*_iter/result/test.data.*.res > $run_dir/result/test.data.res
# TODO so far only multiline (ranking) format supported
    cat $run_dir/result/train.data.res | $ML_FRAMEWORK_DIR/scripts/results_to_triples.pl --ranking | $ML_FRAMEWORK_DIR/scripts/eval.pl --prf --acc >> $run_dir/stats.numbers
    cat $run_dir/result/test.data.res | $ML_FRAMEWORK_DIR/scripts/results_to_triples.pl --ranking | $ML_FRAMEWORK_DIR/scripts/eval.pl --prf --acc >> $run_dir/stats.numbers
    
    print_header $run_dir/stats.numbers "TRAIN_DATA" "TEST_DATA" >> $run_dir/stats.header

    # printing the results
    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    paste $run_dir/stats.header $run_dir/stats.numbers >> $run_dir/stats
    rm $run_dir/stats.header $run_dir/stats.numbers
    
}
