#!/bin/bash

source common.sh

declare -A params
load_params params "$@"
config_file=${params[RUN_DIR]}/config
save_params params $config_file

###################################

exper_type=${params[EXPERIMENT_TYPE]}

case $exper_type in
    train_test) train_test.sh -f $config_file ;;
    cross-valid) ;;
    self-training) ;;
    co-training_align) ;;
    *)  echo "Cannot recognize the type of an experiment: $exper_type" >&2;
        exit
        ;;
esac
