#!/bin/bash

#source $ML_FRAMEWORK_DIR/common.sh
#source $ML_FRAMEWORK_DIR/params.sh


#config_file=$run_dir/config

###################################

#log_dir=$run_dir/log
#mkdir -p $log_dir

function train_test() {
    run_dir=${params[RUN_DIR]}

    train_data=${params[TRAIN_DATA]}
    
    # default values for test_data_names
    test_data_names=${params[DATA_LIST]:-"TRAIN_DATA TEST_DATA"}
    test_data_names=${params[TEST_DATA_LIST]:-$test_data_names}
   
    # make the files empty if existing
    cat /dev/null > $run_dir/stats.numbers
    cat /dev/null > $run_dir/stats.header
    
    for data_name in $test_data_names; do
        data_path=${params[$data_name]}
        if [ -z "$data_path" ]; then
            $ML_FRAMEWORK_DIR/log.sh ERROR "Dataset $data_name is not defined."
            exit
        fi
        make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval eval CONFIG_FILE=$config_file TRAIN_DATA=$train_data TEST_DATA=$data_path >> $run_dir/stats.numbers
    done
   
    print_header $run_dir/stats.numbers $test_data_names >> $run_dir/stats.header

    # printing the results
    echo -e "ML_METHOD:\t" ${params[ML_METHOD]} ${params[ML_PARAMS]} > $run_dir/stats
    paste $run_dir/stats.header $run_dir/stats.numbers >> $run_dir/stats
    rm $run_dir/stats.header $run_dir/stats.numbers
}
