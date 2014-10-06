#!/bin/bash

#source common.sh
#source params.sh


#config_file=$run_dir/config

###################################

#log_dir=$run_dir/log
#mkdir -p $log_dir

function train_test() {
    run_dir=${params[RUN_DIR]}
    train_data=${params[TRAIN_DATA]}
    test_data=${params[TEST_DATA]}

    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_data TEST_DATA=$train_data > $run_dir/stats.numbers
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_data TEST_DATA=$test_data >> $run_dir/stats.numbers
    
    # printing the results
    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    print_ranking_header "TRAIN" > $run_dir/stats.header
    print_ranking_header "TEST" >> $run_dir/stats.header
    paste $run_dir/stats.header $run_dir/stats.numbers >> $run_dir/stats
    rm $run_dir/stats.header $run_dir/stats.numbers
}
