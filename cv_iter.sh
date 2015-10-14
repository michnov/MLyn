#!/bin/bash

source $ML_FRAMEWORK_DIR/common.sh
source $ML_FRAMEWORK_DIR/params.sh
prepare_run_dir
run_dir=${params[RUN_DIR]}

config_file=$run_dir/config
save_params params $config_file

cross_valid_n=${params[CROSS_VALID_N]}
cross_valid_i=${params[CROSS_VALID_I]}
full_data=${params[FULL_DATA]}

# prepare a training and testing fold
mkdir -p $run_dir/data
#base=`basename $train_data`
train_data=$run_dir/data/train.data
test_data=$run_dir/data/test.data
# TODO so far only multiline format supported
$ML_FRAMEWORK_DIR/log.sh DEBUG "zcat $full_data | $ML_FRAMEWORK_DIR/scripts/filter_inst.pl --multiline 1 -n $cross_valid_n --out $cross_valid_i | gzip -c > $train_data"
zcat $full_data | $ML_FRAMEWORK_DIR/scripts/filter_inst.pl --multiline 1 -n $cross_valid_n --out $cross_valid_i | gzip -c > $train_data
zcat $full_data | $ML_FRAMEWORK_DIR/scripts/filter_inst.pl --multiline 1 -n $cross_valid_n --in $cross_valid_i | gzip -c > $test_data
$ML_FRAMEWORK_DIR/log.sh DEBUG "after line filter"

# train and test the models
make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir TRAIN_DATA=$train_data TEST_DATA=$train_data >> $run_dir/stats
make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir TRAIN_DATA=$train_data TEST_DATA=$test_data >> $run_dir/stats
