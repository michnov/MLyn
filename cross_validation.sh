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
    
#cat $(TTE_DIR)/result/train.$(DATA_SOURCE).cv_out_[0-9][0-9].$(ML_ID).res > $(TTE_DIR)/result/train.$(DATA_SOURCE).out.$(ML_ID).res; \
#	cat $(TTE_DIR)/result/train.$(DATA_SOURCE).out.$(ML_ID).res | scripts/results_to_triples.pl $(RANK_FLAG) | $(SCRIPT_DIR)/eval.pl $(RANK_EVAL_FLAG) >> $(STATS_FILE); \
#	cat $(TTE_DIR)/result/train.$(DATA_SOURCE).cv_in_[0-9][0-9].$(ML_ID).res > $(TTE_DIR)/result/train.$(DATA_SOURCE).in.$(ML_ID).res; \
#	cat $(TTE_DIR)/result/train.$(DATA_SOURCE).in.$(ML_ID).res | scripts/results_to_triples.pl $(RANK_FLAG) | $(SCRIPT_DIR)/eval.pl $(RANK_EVAL_FLAG) >> $(STATS_FILE); \
#	touch $(TTE_DIR)/done.$(ML_ID)
   
#    # all numbers
#    paste $run_dir/*_sample_*/stats >> $run_dir/stats.numbers
#    
#    # a header used for sample results
#    echo "TRAIN_SAMPLE" > $run_dir/stats.header
#    print_header $run_dir/stats.numbers "TRAIN" "TEST" >> $run_dir/stats.header
#    
#    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
#    paste $run_dir/stats.header $run_dir/stats.numbers >> $run_dir/stats
#    sed -i 's/$/|/' $run_dir/stats
#    rm $run_dir/stats.header $run_dir/stats.numbers
}
