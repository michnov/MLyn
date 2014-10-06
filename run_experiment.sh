#!/bin/bash

source $ML_FRAMEWORK_DIR/common.sh
source $ML_FRAMEWORK_DIR/params.sh
prepare_run_dir

config_file=${params[RUN_DIR]}/config
save_params params $config_file

source $ML_FRAMEWORK_DIR/iterate_featsets.sh
source $ML_FRAMEWORK_DIR/iterate_mlmethods.sh

source $ML_FRAMEWORK_DIR/train_test.sh
source $ML_FRAMEWORK_DIR/self_training.sh


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
            *)  $ML_FRAMEWORK_DIR/log.sh ERROR "Cannot recognize the type of an experiment: $exper_type" >&2;
                exit
                ;;
        esac
    fi
fi
