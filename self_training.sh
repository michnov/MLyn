#!/bin/bash


function self_training() {
    #source common.sh
    #source params.sh

    run_dir=${params[RUN_DIR]}

    #config_file=$run_dir/config

    ###################################

    iter_count=${params[ITER_COUNT]-"10"}
    max_loss=${params[MAX_LOSS]}
    unlabeled_split_size=${params[UNLABELED_SPLIT_SIZE]}
    unlabeled_data=${params[UNLABELED_DATA]}
    train_data=${params[TRAIN_DATA]}
    
    # check if the unlabeled data is a single file (and should be splitted) or it is multiple files defined by a wildcard
    unlabeled_count=`ls $unlabeled_data | wc -l`
    if [ $unlabeled_count -eq 1 ]; then
        if [ ! -z $unlabeled_split_size ]; then
        ./log.sh DEBUG "UNLABELED SPLIT SIZE = $unlabeled_split_size"
            data_stem=`make -s -f makefile.preprocess data_stem DATA=${params[UNLABELED_DATA]}`
            zcat $unlabeled_data | scripts/split_on_empty_line.pl $unlabeled_split_size $run_dir/data/$data_stem.part
            unlabeled_data=$run_dir/data/$data_stem.part*
        fi
    elif [ $unlabeled_count -eq 0 ]; then
        ./log.sh ERROR "UNLABELED_DATA must be defined."
        exit 1
    fi
    ./log.sh DEBUG "Unlabeled data stored in: $unlabeled_data"

    i=0
    iter=`printf "%03d" $i`
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TEST_DATA=${params[TRAIN_DATA]} > >(tee $run_dir/stats)
    make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TEST_DATA=${params[TEST_DATA]} > >(tee -a $run_dir/stats)
    label_model_path=`make -s -f makefile.train_test_eval model_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter`
    #train_data_ready=`make -s -f makefile.preprocess data_ready_path CONFIG_FILE=$config_file DATA_DIR=$run_dir/data DATA=${params[TRAIN_DATA]}`
    for (( i=1; i<=$iter_count; i++ )); do
        old_iter=$iter
        iter=`printf "%03d" $i`

        file_i=1
        for file_part in $unlabeled_data; do
            file_i_str=`printf "%03d" $file_i`
            
            result_file=`make -s -f makefile.train_test_eval result_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$old_iter TRAIN_DATA=$train_data TEST_DATA=$file_part`
            sys_labeled_data=$run_dir/iter_$iter/data/`basename $file_part`
            
            run_in_parallel \
                "make -s -f makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$old_iter TRAIN_DATA=$train_data TEST_DATA=$file_part; \
                    mkdir -p $run_dir/iter_$iter/data; \
                    ./log.sh INFO \"Adding system labels to the unlabeled data, if the minimum loss is <= $max_loss: $file_part + $result_file => $sys_labeled_data\"; \
                    scripts/paste_data_results.sh $file_part $result_file | scripts/filter_by_loss.pl $max_loss | scripts/discretize_losses.pl | gzip -c > $sys_labeled_data; \
                    touch $run_dir/iter_$iter/done.$file_i_str" \
                "unlabeled.part.$file_i_str" -50 $run_dir/iter_$iter/log 0

            echo $sys_labeled_data >> $run_dir/iter_$iter/data.to_merge.list
            ((file_i++))
        done

        # wait until all experiments are acomplished
        ./log.sh INFO "Waiting for all the experiments to be completed..."
        while [ `ls $run_dir/iter_$iter/done.* 2> /dev/null | wc -l` -lt $unlabeled_count ]; do
            ./log.sh DEBUG `ls $run_dir/iter_$iter/done.* 2> /dev/null | wc -l` $unlabeled_count
            sleep 10
        done

        ./log.sh INFO "Merging all newly labeled data..."
        #echo ${params[TRAIN_DATA]} >> $run_dir/iter_$iter/data.to_merge.list
        train_data=$run_dir/iter_$iter/data/all.data
        cat $run_dir/iter_$iter/data.to_merge.list | xargs zcat | gzip -c > $train_data

        ./log.sh INFO "Training and testing with the initial model: $label_model_path"
        make -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TRAIN_DATA]} INITIAL_MODEL=$label_model_path > >(tee $run_dir/stats)
        make -f makefile.train_test_eval eval CONFIG_FILE=$config_file RUN_DIR=$run_dir/iter_$iter TRAIN_DATA=$train_data TEST_DATA=${params[TEST_DATA]} INITIAL_MODEL=$label_model_path > >(tee -a $run_dir/stats)
    done
}

#    mkdir -p $(ST_DIR)/data/$$iter; \
#    mkdir -p $(ST_DIR)/model/$$iter; \
#    mkdir -p $(ST_DIR)/result/$$iter; \
#    mkdir -p $(ST_DIR)/log/$$iter; \
#    make -s test DATA_SOURCE=$(DATA_SOURCE) TRAIN_DATA_NAME=$(TRAIN_DATA_NAME) TEST_DATA_NAME=$(UNLABELED_DATA_NAME) RANKING=$(RANKING) ML_METHOD=$(ML_METHOD) ML_PARAMS="$(ML_PARAMS)" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(ST_DIR)/model/$$old_iter RESULT_DIR=$(ST_DIR)/result/$$iter QSUB_LOG_DIR=$(ST_DIR)/log/$$iter/$(ML_ID); \
#    resolved_data=$(ST_DIR)/data/$$iter/resolved_unlabeled.table; \
#    scripts/paste_data_results.sh $(UNLABELED_SET) $(ST_DIR)/result/$$iter/$(UNLABELED_DATA_ID).$(ML_METHOD).$(ML_PARAMS_HASH).res | scripts/filter_by_loss.pl $(MAX_LOSS) | scripts/discretize_losses.pl | gzip -c > $$resolved_data; \
#    new_train_data=$(ST_DIR)/data/$$iter/new_train.$(DATA_SOURCE).idx.table; \
#    zcat $(TRAIN_SET) $$resolved_data | gzip -c > $$new_train_data; \
#    ln -s $(TRAIN_SET) $(ST_DIR)/data/$$iter/$(TRAIN_DATA_NAME).$(DATA_SOURCE).idx.table; \
#    ln -s $(TEST_SET) $(ST_DIR)/data/$$iter/$(TEST_DATA_NAME).$(DATA_SOURCE).idx.table; \
#    make -s eval DATA_SOURCE=$(DATA_SOURCE) TRAIN_DATA_NAME=new_train TEST_DATA_NAME=$(TRAIN_DATA_NAME) RANKING=$(RANKING) ML_METHOD=$(ML_METHOD) ML_PARAMS="$(ML_PARAMS)" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(ST_DIR)/data/$$iter MODEL_DIR=$(ST_DIR)/model/$$iter RESULT_DIR=$(ST_DIR)/result/$$iter QSUB_LOG_DIR=$(ST_DIR)/log/$$iter/$(ML_ID) >> $(ST_DIR)/acc.$$iter.$(ML_ID); \
#    make -s eval DATA_SOURCE=$(DATA_SOURCE) TRAIN_DATA_NAME=new_train TEST_DATA_NAME=$(TEST_DATA_NAME) RANKING=$(RANKING) ML_METHOD=$(ML_METHOD) ML_PARAMS="$(ML_PARAMS)" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(ST_DIR)/data/$$iter MODEL_DIR=$(ST_DIR)/model/$$iter RESULT_DIR=$(ST_DIR)/result/$$iter QSUB_LOG_DIR=$(ST_DIR)/log/$$iter/$(ML_ID) >> $(ST_DIR)/acc.$$iter.$(ML_ID); \

#make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TRAIN_DATA]} > >(tee -a $run_dir/stats)
#make -s -f makefile.train_test_eval eval CONFIG_FILE=$config_file TEST_DATA=${params[TEST_DATA]} > >(tee -a $run_dir/stats)
