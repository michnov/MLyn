#!/bin/bash

source $ML_FRAMEWORK_DIR/params.sh
prepare_run_dir
config_file=${params[RUN_DIR]}/config
save_params params $config_file

info_file=${params[RUN_DIR]}/info
stats_file=${params[RUN_DIR]}/stats

echo -en "INFO:\t" >> $info_file
echo -en ${params[DATE]}"\t" >> $info_file
echo -en "`git rev-parse --abbrev-ref HEAD`:`git rev-parse HEAD | cut -c 1-10`\t" >> $info_file
echo ${params[D]} >> $info_file

$ML_FRAMEWORK_DIR/run_experiment.sh -f $config_file
cat $stats_file >> $info_file
cp $info_file $stats_file
rm $info_file

$ML_FRAMEWORK_DIR/log.sh INFO "Complete results stored in: $stats_file"
