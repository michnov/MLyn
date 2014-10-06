#!/bin/bash

source common.sh
source params.sh

config_file=${params[RUN_DIR]}/config

source iterate_featsets.sh
source iterate_mlmethods.sh

source train_test.sh


###### ITERATE OVER FEATSETS #######
if [ ${params[FEATSET_LIST]+_} ]; then
    iterate_featsets

###### ONE OR NO FEATSET ###########
else
    run_on_featset
    
    ####### ITERATE OVER ML_METHODS ########
    if [ ${params[ML_METHOD_LIST]+_} ]; then
        iterate_mlmethods
    
    #### SINGLE FEATSET, SINGLE MLMETHOD ####
    else
        exper_type=${params[EXPERIMENT_TYPE]}
        case $exper_type in
            train_test) train_test ;;
            cross-valid) ;;
            self-training) ./self_training.sh -f $config_file ;;
            co-training_align) ;;
            *)  ./log.sh ERROR "Cannot recognize the type of an experiment: $exper_type" >&2;
                exit
                ;;
        esac
    fi
fi
