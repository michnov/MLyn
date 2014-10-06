#!/bin/bash

unlabeled_data=$1
unlabeled_split_size=$2
run_dir=$3
unlabeled_count=`ls $unlabeled_data | wc -l`
if [ $unlabeled_count -eq 1 ]; then
    if [ ! -z $unlabeled_split_size ]; then
        $ML_FRAMEWORK_DIR/log.sh DEBUG "UNLABELED SPLIT SIZE = $unlabeled_split_size"
        file_stem=`$ML_FRAMEWORK_DIR/scripts/file_stem.pl "$unlabeled_data"`
        $ML_FRAMEWORK_DIR/log.sh DEBUG "FILE_STEM = $file_stem"
        zcat $unlabeled_data | $ML_FRAMEWORK_DIR/scripts/split_on_empty_line.pl $unlabeled_split_size $run_dir/data/$file_stem.part
        unlabeled_data=$run_dir/data/$file_stem.part*
    fi
elif [ $unlabeled_count -eq 0 ]; then
    $ML_FRAMEWORK_DIR/log.sh ERROR "UNLABELED_DATA must be defined."
    exit 1
fi
echo "$unlabeled_data"
