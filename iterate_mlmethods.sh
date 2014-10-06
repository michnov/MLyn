#!/bin/bash


function iterate_mlmethods() {
    #$ML_FRAMEWORK_DIR/log.sh INFO "Running $0..."

    #source $ML_FRAMEWORK_DIR/common.sh
    #source $ML_FRAMEWORK_DIR/params.sh

    #config_file=${params[RUN_DIR]}/config

    ###################################

    mlmethod_list=${params[ML_METHOD_LIST]}
    run_dir=${params[RUN_DIR]}

    result_template=conf/result.template

    $ML_FRAMEWORK_DIR/log.sh DEBUG "Filtering the ML method list: $mlmethod_list => $run_dir/mlmethod_per_line.list"
    cat $mlmethod_list | grep -v "^#" > $run_dir/mlmethod_per_line.list
    if [ ${params[RANKING]}. == 1. ]; then
        cat $run_dir/mlmethod_per_line.list | grep "ranking" > $run_dir/mlmethod_per_line.list.tmp
        cp $run_dir/mlmethod_per_line.list.tmp $run_dir/mlmethod_per_line.list
        rm $run_dir/mlmethod_per_line.list.tmp
        result_template=conf/result.ranking.template
    fi

#    $ML_FRAMEWORK_DIR/log.sh INFO "Preprocessing the data used in the experiments..."
#    cat $run_dir/mlmethod_per_line.list | cut -f1 -d: | sort | uniq | while read ml_method; do
#       make -s -f $ML_FRAMEWORK_DIR/makefile.train_test_eval preprocess CONFIG_FILE=$config_file ML_METHOD=$ml_method  
#    done

    iter=000
    # run an experiment for every ML method
    cat $run_dir/mlmethod_per_line.list | while read ml_method_info; do
        iter=`perl -e 'my $x = shift @ARGV; $x++; printf "%03s", $x;' $iter`
        
        ml_method=`echo $ml_method_info | cut -f1 -d':'`
        ml_params=`echo $ml_method_info | cut -f2- -d':'`
        ml_method_sha=`echo "$ml_method_info" | shasum | cut -c 1-5`

        run_subdir=$run_dir/$iter.$ml_method_sha.mlmethod
        #mkdir -p $run_subdir
        #echo_err $run_subdir

        $ML_FRAMEWORK_DIR/log.sh INFO "Running an experiment no. $iter using the ML method $ml_method with params ($ml_params)"
        $ML_FRAMEWORK_DIR/log.sh DEBUG "Its running directory is: $run_subdir"

        #data_dir=${params[DATA_DIR]-$run_dir/data}
        #DATA_DIR=$data_dir \

        run_in_parallel \
            "$ML_FRAMEWORK_DIR/run_experiment.sh \
                -f $config_file \
                RUN_DIR=$run_subdir \
                ML_METHOD_LIST= \
                ML_METHOD=$ml_method \
                ML_PARAMS='$ml_params'; \
                touch $run_subdir/done;" \
            "mlmethod_exper.$ml_method_sha" -20 $run_subdir/log 2
    done

    # wait until all experiments are acomplished
    $ML_FRAMEWORK_DIR/log.sh INFO "Waiting for all the experiments to be completed..."
    mlmethods_count=`cat $run_dir/mlmethod_per_line.list | wc -l`
    while [ `ls $run_dir/*.mlmethod/done 2> /dev/null | wc -l` -lt $mlmethods_count ]; do
        sleep 5
    done

    # collect results
    $ML_FRAMEWORK_DIR/log.sh INFO "Collecting results of the experiments to: $run_dir/stats"
    i=0
    for stats_part in $run_dir/*.mlmethod/stats; do
        if [ $i -eq 0 ]; then
            cat $stats_part | cut -f1 > $run_dir/stats
        fi
        cat $stats_part | cut -f1 --complement | paste $run_dir/stats - > $run_dir/stats.tmp
        cp $run_dir/stats.tmp $run_dir/stats
        rm $run_dir/stats.tmp
    done
    sed -i 's/|$//' $run_dir/stats
}
