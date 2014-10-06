#!/bin/bash

source common.sh
source params.sh

run_dir=${params[RUN_DIR]}

config_file=$run_dir/config

###################################

iter_count=${params[ITER_COUNT]-"10"}
unlabeled_prefix=${params[UNLABELED_SPLIT_PREFIX]}
max_loss=${params[MAX_LOSS]}

i=0
iter=`printf "%03d" $i`
./train_test.sh -f $config_file RUN_DIR=$run_dir/"$iter"_iter DATA_DIR=$run_dir/data
for (( i=1; i<=$iter_count; i++ )); do
    old_iter=$iter
    iter=`printf "%03d" $i`
    for file_part in $unlabeled_prefix*; do
        make -s -f makefile.train_test_eval test CONFIG_FILE=$config_file RUN_DIR=$run_dir/"$old_iter"_iter DATA_DIR=$run_dir/data TEST_DATA=$file_part
        result_file=`make -s -f makefile.train_test_eval result_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/"$old_iter"_iter DATA_DIR=$run_dir/data TEST_DATA=$file_part`
        sys_labeled_data=`make -s -f makefile.train_test_eval data_orig_path CONFIG_FILE=$config_file RUN_DIR=$run_dir/"$iter"_iter _DATA=$file_part`
        mkdir -p `dirname $sys_labeled_data`
        ./log.sh INFO "Adding system labels to the unlabeled data, if the minimum loss is <= $max_loss: $file_part + $result_file => $sys_labeled_data"
        scripts/paste_data_results.sh $file_part $result_file | scripts/filter_by_loss.pl $max_loss | scripts/discretize_losses.pl | gzip -c > $sys_labeled_data
        make -s -f makefile.preprocess CONFIG_FILE=$config_file RUN_DIR=$run_dir/"$iter"_iter _DATA=$file_part
    done
done

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

