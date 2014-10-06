#!/bin/bash

source common.sh
source params.sh

config_file=${params[RUN_DIR]}/config

###################################

make -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TRAIN_DATA]}
make -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TEST_DATA]}
