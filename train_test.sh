#!/bin/bash

source common.sh

declare -A params
load_params params "$@"
config_file=${params[RUN_DIR]}/config
save_params params $config_file

###################################

make -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TRAIN_DATA]}
make -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TEST_DATA]}

touch $(TTE_DIR)/done.$$ml_id;"; \
