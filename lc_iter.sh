#!/bin/bash

source $ML_FRAMEWORK_DIR/common.sh
source $ML_FRAMEWORK_DIR/params.sh
prepare_run_dir
run_dir=${params[RUN_DIR]}

config_file=$run_dir/config
save_params params $config_file

train_data=${params[TRAIN_DATA]}
train_sample_size=${params[TRAIN_SAMPLE_SIZE]}
test_data=${params[DEV_DATA]}

# prepare a randomly selected data sample of size $train_size
mkdir -p $run_dir/data
zcat $train_data | $ML_FRAMEWORK_DIR/scripts/count_ranking_instances.pl > $run_dir/train.size
train_size=`cat $run_dir/train.size`
$ML_FRAMEWORK_DIR/scripts/rand_seq.pl $train_size $train_sample_size 1 | $ML_FRAMEWORK_DIR/scripts/partition_idx.pl -f $run_dir/train.size > $run_dir/train.sample.idx
base=`basename $train_data`
zcat $train_data | $ML_FRAMEWORK_DIR/scripts/filter_inst.pl --multiline 1 --in $run_dir/train.sample.idx | gzip -c > $run_dir/data/$base
train_data=$run_dir/data/$base

# train and test the models
make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir TRAIN_DATA=$train_data TEST_DATA=$train_data >> $run_dir/stats
make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir TRAIN_DATA=$train_data TEST_DATA=$test_data >> $run_dir/stats
