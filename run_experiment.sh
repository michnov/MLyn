#!/bin/bash

source common.sh
source params.sh

config_file=${params[RUN_DIR]}/config

###################################

exper_type=${params[EXPERIMENT_TYPE]}

case $exper_type in
    train_test) ./train_test.sh -f $config_file ;;
    cross-valid) ;;
    self-training) ;;
    co-training_align) ;;
    *)  ./log.sh ERROR "Cannot recognize the type of an experiment: $exper_type" >&2;
        exit
        ;;
esac
