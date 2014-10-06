#!/bin/bash

#source common.sh
#source params.sh


#config_file=$run_dir/config

###################################

#log_dir=$run_dir/log
#mkdir -p $log_dir

function print_header {
    echo "TRAIN:"
    echo
    echo
    echo "TEST:"
    echo
    echo
}

function train_test() {
    run_dir=${params[RUN_DIR]}
    train_data=${params[TRAIN_DATA]}
    test_data=${params[TEST_DATA]}

    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_data TEST_DATA=$train_data >> $run_dir/stats.numbers
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_data TEST_DATA=$test_data >> $run_dir/stats.numbers
    
    # printing the results
    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    print_header | paste - $run_dir/stats.numbers >> $run_dir/stats
}
