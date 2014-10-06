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
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_data TEST_DATA=$train_data > >(tee $run_dir/stats)
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_data TEST_DATA=$test_data > >(tee -a $run_dir/stats)
}
