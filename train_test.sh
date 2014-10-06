#!/bin/bash

source common.sh
source params.sh

run_dir=${params[RUN_DIR]}

config_file=$run_dir/config

###################################

#log_dir=$run_dir/log
#mkdir -p $log_dir

make -s -f makefile.preprocess preprocess CONFIG_FILE=$config_file DATA=${params[TRAIN_DATA]}
train_ready=`make -s -f makefile.preprocess data_ready_path CONFIG_FILE=$config_file DATA=${params[TRAIN_DATA]}`
echo $train_ready
make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_ready TEST_DATA=$train_ready > >(tee -a $run_dir/stats)

make -s -f makefile.preprocess preprocess CONFIG_FILE=$config_file DATA=${params[TEST_DATA]}
test_ready=`make -s -f makefile.preprocess data_ready_path CONFIG_FILE=$config_file DATA=${params[TEST_DATA]}`
echo $test_ready
make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_ready TEST_DATA=$test_ready > >(tee -a $run_dir/stats)
