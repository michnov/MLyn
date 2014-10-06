#!/bin/bash

source $ML_FRAMEWORK_DIR/params.sh
prepare_run_dir
config_file=${params[RUN_DIR]}/config
save_params params $config_file

stats_file=${params[RUN_DIR]}/stats

echo -en "INFO:\t" >> $stats_file
echo -en ${params[DATE]}"\t" >> $stats_file
echo -en "`git rev-parse --abbrev-ref HEAD`:`git rev-parse HEAD | cut -c 1-10`\t" >> $stats_file
echo ${params[D]}

$ML_FRAMEWORK_DIR/run_experiment.sh -f $config_file

$ML_FRAMEWORK_DIR/log.sh INFO "Complete results stored in: $stats_file"
