#!/bin/bash

source common.sh
source params.sh

run_dir=${params[RUN_DIR]}

config_file=$run_dir/config

###################################

#log_dir=$run_dir/log
#mkdir -p $log_dir

make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TRAIN_DATA]} > >(tee $run_dir/stats)
make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TEST_DATA]} > >(tee $run_dir/stats)
