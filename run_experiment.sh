#!/bin/bash

source common.sh
source params.sh
prepare_run_dir

config_file=${params[RUN_DIR]}/config
save_params params $config_file

source iterate_featsets.sh
source iterate_mlmethods.sh

source train_test.sh
source self_training.sh


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
            self-training) self_training ;;
            co-training_align) ;;
            *)  ./log.sh ERROR "Cannot recognize the type of an experiment: $exper_type" >&2;
                exit
                ;;
        esac
    fi
fi
