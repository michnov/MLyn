#!/bin/bash

source common.sh

declare -A params
load_params params "$@"
config_file=${params[RUN_DIR]}/config
save_params params $config_file

###################################

mlmethod_list=${params[MLMETHOD_LIST]}
run_dir=${params[RUN_DIR]}

result_template=conf/result.template

iter=000
cat $mlmethod_list | grep -v "^#" > $run_dir/mlmethod_per_line.list
if [ ${params[RANKING]}. == 1. ]; then
    cat $run_dir/mlmethod_per_line.list | grep "ranking" > $run_dir/mlmethod_per_line.list.tmp
    cp $run_dir/mlmethod_per_line.list.tmp $run_dir/mlmethod_per_line.list
    result_template=conf/result.ranking.template
fi

# run an experiment for every feature set
cat $run_dir/mlmethod_per_line.list | while read ml_method_info; do
    iter=`perl -e 'my $x = shift @ARGV; $x++; printf "%03s", $x;' $iter`
    
    ml_method=`echo $ml_method_info | cut -f1 -d':'`
    ml_params="`echo $ml_method_info | cut -f2- -d':'`"
    ml_method_sha=`echo "$ml_method_info" | shasum | cut -c 1-5`

    run_subdir=$run_dir/$iter.$ml_method_sha.mlmethod
    mkdir -p $run_subdir

    # print a header into a subprocess stats file
    echo $ml_method $ml_params >> $run_subdir/stats

    run_in_parallel \
        "./run_experiment.sh \
            -f $config_file \
            ML_METHOD=$ml_method \
            ML_PARAMS=$ml_params; \
            touch $run_subdir/done;" \
        "mlmethod_exper.$ml_method_sha" -20 $run_subdir/log 2
done

# wait until all experiments are acomplished
mlmethods_count=`cat $run_dir/mlmethod_per_line.list | wc -l`
while [ `ls $run_dir/*.mlmethod/done 2> /dev/null | wc -l` -lt $mlmethods_count ]; do
    sleep 5
done

# collect results
paste $result_template $run_dir/*.mlmethod/stats >> $run_dir/stats
