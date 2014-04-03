SHELL:=/bin/bash

############################################## VARIABLES #####################################################################

DATE := $(shell date +%Y-%m-%d_%H-%M-%S)

#------------------------------------------- LRC ---------------------------------------------------

LRC=1
JOBS_NUM=100

ifeq ($(LRC),1)
LRC_FLAGS=-p --qsub '-hard -l mem_free=6G -l act_mem_free=6G -l h_vmem=6G' --jobs ${JOBS_NUM}
endif

#------------------------------------------- DIRS ---------------------------------------------------

SCRIPT_DIR=scripts

#DATA_DIR=data
#MODEL_DIR=model
#RESULT_DIR=result
#LOG_DIR=log
#QSUB_LOG_DIR=$(LOG_DIR)/qsubmit

#------------------------------------------- DATA ---------------------------------------------------

DATA_SOURCE=pcedt
#DATA_SOURCE=czeng

TRAIN_DATA_NAME=train
TEST_DATA_NAME=dev

RANKING=0

TRAIN_DATA_ID := $(TRAIN_DATA_NAME).$(DATA_SOURCE)
TEST_DATA_ID := $(TEST_DATA_NAME).$(DATA_SOURCE)

ifdef CROSS_VALID_I
TEST_DATA_NAME := $(TRAIN_DATA_NAME)
CROSS_VALID_I_STR := $(shell printf "%02d" $(CROSS_VALID_I))
TRAIN_DATA_ID := $(TRAIN_DATA_NAME).$(DATA_SOURCE).cv_out_$(CROSS_VALID_I_STR)
TEST_DATA_ID := $(TEST_DATA_NAME).$(DATA_SOURCE).cv_$(CROSS_VALID_FOLD)_$(CROSS_VALID_I_STR)
FILTER_INST_PARAMS=--multiline $(RANKING) -n $(CROSS_VALID_N) --$(CROSS_VALID_FOLD) $(CROSS_VALID_I)
endif

TRAIN_SET = $(DATA_DIR)/$(TRAIN_DATA_NAME).$(DATA_SOURCE).idx.table
TEST_SET = $(DATA_DIR)/$(TEST_DATA_NAME).$(DATA_SOURCE).idx.table

#------------------------------------------- ML ---------------------------------------------------

ML_METHOD=maxent
#ML_METHOD=vw
#ML_METHOD=sklearn.decision_trees

ifeq ($(ML_METHOD),vw)
ML_PARAMS=--passes 20
endif

ML_PARAMS_HASH = $(shell echo "$(ML_PARAMS)" | shasum | cut -c 1-5)
ML_ID=$(ML_METHOD).$(ML_PARAMS_HASH)

TRAIN_QSUBMIT=$(SCRIPT_DIR)/qsubmit_sleep --jobname="train.$(ML_ID).$(TRAIN_DATA_ID)" --mem="15g" --priority="0" --logdir="$(QSUB_LOG_DIR)" --sync
TEST_QSUBMIT=$(SCRIPT_DIR)/qsubmit_sleep  --jobname="test.$(ML_ID).$(TEST_DATA_ID)" --mem="15g" --priority="0" --logdir="$(QSUB_LOG_DIR)" --sync

VW_APP=/net/work/people/mnovak/tools/x86_64/vowpal_wabbit/vowpalwabbit/vw

#--------------------------------------- PREPARE DATA ----------------------------------------------------------

extract_data : $(TRAIN_SET) $(TEST_SET)

$(DATA_DIR)/%.$(DATA_SOURCE).idx.table : $(DATA_DIR)/%.$(DATA_SOURCE).table
	if [ $(RANKING) -eq 0 ]; then \
		zcat $< | \
			$(SCRIPT_DIR)/index_class.pl $(DATA_DIR)/train.$(DATA_SOURCE).idx | \
			gzip -c > $@; \
	else \
		cp $< $@; \
	fi

.SECONDARY : $(DATA_DIR)/train.$(DATA_SOURCE).table $(DATA_DIR)/dev.$(DATA_SOURCE).table $(DATA_DIR)/eval.$(DATA_SOURCE).table

clean_data :
	-rm $(TRAIN_SET) $(TEST_SET)

#----------------------------------------- TRAIN --------------------------------------------------------------


train : $(MODEL_DIR)/$(TRAIN_DATA_ID).$(ML_ID).model

$(MODEL_DIR)/$(TRAIN_DATA_ID).maxent.$(ML_PARAMS_HASH).model : $(TRAIN_SET)
	$(TRAIN_QSUBMIT) 'zcat $< | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/maxent.train.pl $@' $@
$(MODEL_DIR)/$(TRAIN_DATA_ID).vw.$(ML_PARAMS_HASH).model : $(TRAIN_SET)
	$(TRAIN_QSUBMIT) \
		'zcat $< | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl | gzip -c > /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.table.$$$$; \
		$(VW_APP) -d /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.table.$$$$ -f $@ --sequence_max_length 10000 --compressed \
			--oaa `zcat $< | cut -f 1 | sort -n | tail -n1` $(ML_PARAMS) \
			-c -k --cache_file /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.cache.$$$$; \
		rm /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.table.$$$$; \
		rm /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.cache.$$$$' $@
$(MODEL_DIR)/$(TRAIN_DATA_ID).vw.ranking.$(ML_PARAMS_HASH).model : $(TRAIN_SET)
	$(TRAIN_QSUBMIT) \
		'zcat $< | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl -m | gzip -c > /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.ranking.table.$$$$; \
		$(VW_APP) -d /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.ranking.table.$$$$ -f $@ --sequence_max_length 10000 --compressed \
			--csoaa_ldf m $(ML_PARAMS) \
			-c -k --cache_file /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.ranking.cache.$$$$; \
		rm /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.ranking.table.$$$$; \
		rm /COMP.TMP/$(TRAIN_DATA_ID).idx.vw.ranking.cache.$$$$' $@
$(MODEL_DIR)/$(TRAIN_DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model : $(TRAIN_SET)
	$(TRAIN_QSUBMIT) 'zcat $< | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/sklearn.train.py $* "$(ML_PARAMS)" $@' $@

clean_train:
	-rm $(MODEL_DIR)/$(TRAIN_DATA_ID).$(ML_ID).model

#----------------------------------------- TEST --------------------------------------------------------------


test : $(RESULT_DIR)/$(TEST_DATA_ID).$(ML_ID).res

$(RESULT_DIR)/$(TEST_DATA_ID).maxent.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(TRAIN_DATA_ID).maxent.$(ML_PARAMS_HASH).model $(TEST_SET)
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/maxent.test.pl $< > $@' $@
$(RESULT_DIR)/$(TEST_DATA_ID).vw.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(TRAIN_DATA_ID).vw.$(ML_PARAMS_HASH).model $(TEST_SET)
	$(TEST_QSUBMIT) \
		'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl --test | gzip -c > /COMP.TMP/$(TEST_DATA_ID).idx.vw.table.$$$$; \
		zcat /COMP.TMP/$(TEST_DATA_ID).idx.vw.table.$$$$ | $(VW_APP) -t -i $< -p /COMP.TMP/$(TEST_DATA_ID).vw.res.tmp.$$$$ --sequence_max_length 10000; \
		rm /COMP.TMP/$(TEST_DATA_ID).idx.vw.table.$$$$; \
		perl -pe '\''$$_ =~ s/^(.*?)\..*? (.*?)$$/$$2\t$$1/;'\'' < /COMP.TMP/$(TEST_DATA_ID).vw.res.tmp.$$$$ > $@; \
		rm /COMP.TMP/$(TEST_DATA_ID).vw.res.tmp.$$$$' $@
$(RESULT_DIR)/$(TEST_DATA_ID).vw.ranking.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(TRAIN_DATA_ID).vw.ranking.$(ML_PARAMS_HASH).model $(TEST_SET)
	$(TEST_QSUBMIT) \
		'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl -m | gzip -c > /COMP.TMP/$(TEST_DATA_ID).idx.vw.ranking.table.$$$$; \
		zcat /COMP.TMP/$(TEST_DATA_ID).idx.vw.ranking.table.$$$$ | $(VW_APP) -t -i $< -p $@ --sequence_max_length 10000; \
		rm /COMP.TMP/$(TEST_DATA_ID).idx.vw.ranking.table.$$$$' $@
$(RESULT_DIR)/$(TEST_DATA_ID).sklearn.%.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(TRAIN_DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model $(TEST_SET)
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_inst.pl $(FILTER_INST_PARAMS) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/sklearn.test.py $< > $@' $@

clean_test:
	-rm $(RESULT_DIR)/$(TEST_DATA_ID).$(ML_ID).res

		#inst_num=`grep "^$$" $@ | wc -l`; \
		#if ["$$inst_num" -ne 1988 -a "$$inst_num" -ne 19294]; then \
		#	cp /COMP.TMP/$*.$(DATA_SOURCE).idx.vw.ranking.table.$$$$ $(QSUB_LOG_DIR)/$*.$(DATA_SOURCE).idx.vw.ranking.table.$$$$.$$$$; \
		#fi; 
#----------------------------------------- EVAL --------------------------------------------------------------

ifeq ($(RANKING),1)
RANK_FLAG=--ranking
RANK_EVAL_FLAG=--acc --prf
endif

eval : $(RESULT_DIR)/$(TEST_DATA_ID).$(ML_ID).res
	cat $< | scripts/results_to_triples.pl $(RANK_FLAG) | $(SCRIPT_DIR)/eval.pl $(RANK_EVAL_FLAG)

#---------------------------------------- CLEAN -------------------------------------------------------

clean : clean_test clean_train

#======================================== ML SCENARIOS ==============================================================

#RUNS_DIR=tmp
CONF_DIR=conf

STATS_FILE=results
ML_METHOD_LIST=$(CONF_DIR)/ml_methods
FEATSET_LIST=$(CONF_DIR)/featset_list
RESULT_TEMPLATE=$(CONF_DIR)/result.template
ifeq ($(RANKING),1)
RESULT_TEMPLATE=$(CONF_DIR)/result.ranking.template
endif

CROSS_VALID_N=0

#--------------------------------- train, test, eval for all metnods -------------------------------------

TTE_DIR=$(RUNS_DIR)/tte_$(DATE)
TTE_FEATS_DIR=$(RUNS_DIR)/tte_feats_$(DATE)

ifeq ($(RANKING),1)
RANKING_GREP=| grep "ranking"
endif

tte : $(TTE_DIR)/all.acc
	cat $< >> $(STATS_FILE)
$(TTE_DIR)/all.acc :
	mkdir -p $(TTE_DIR)
	mkdir -p $(TTE_DIR)/log
	mkdir -p $(TTE_DIR)/model
	mkdir -p $(TTE_DIR)/result
	echo "$(DATA_DIR)/train.$(DATA_SOURCE).table"
	echo -e "FEATS:\t$(FEAT_DESCR)" >> $@; \
	echo -en "INFO:\t" >> $@; \
	echo -en "$(DATE)\t$(DATA_SOURCE)\t`git rev-parse --abbrev-ref HEAD`:`git rev-parse HEAD | cut -c 1-10`" >> $@; \
	echo -en "\t`zcat $(DATA_DIR)/train.$(DATA_SOURCE).table | cut -f1 | sort | shasum | cut -c 1-10`\t" >> $@; \
	echo $(FEAT_LIST) | shasum | cut -c 1-10 >> $@;
	iter=000; \
	cat $(ML_METHOD_LIST) $(RANKING_GREP) | grep -v "^#" | while read i ; do \
		iter=`perl -e 'my $$x = shift @ARGV; $$x++; printf "%03s", $$x;' $$iter`; \
		ml_method=`echo $$i | cut -f1 -d':'`; \
		ml_params="`echo $$i | cut -f2 -d':'`"; \
		echo "$$ml_params"; \
		ml_params_hash=`echo "$$ml_params" | shasum | cut -c 1-5`; \
		ml_id=$$ml_method.$$ml_params_hash; \
		mkdir -p $(TTE_DIR)/log/$$ml_id; \
		if [ $(CROSS_VALID_N) -gt 0 ]; then \
			qsubmit --jobname="tte.cv.$$ml_id" --mem="1g" --priority="0" --logdir="$(TTE_DIR)/log/$$ml_id" \
				"make -s cross_eval CROSS_VALID_N=$(CROSS_VALID_N) DATA_SOURCE=$(DATA_SOURCE) RANKING=$(RANKING) ML_METHOD=$$ml_method ML_PARAMS=\"$$ml_params\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) TTE_DIR=$(TTE_DIR) STATS_FILE=$(TTE_DIR)/acc.$$iter.$$ml_id;"; \
		else \
			qsubmit --jobname="tte.$$ml_id" --mem="1g" --priority="0" --logdir="$(TTE_DIR)/log/$$ml_id" \
				"echo \"$$ml_method $$ml_params\" >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
				make -s eval DATA_SOURCE=$(DATA_SOURCE) TRAIN_DATA_NAME=train TEST_DATA_NAME=train RANKING=$(RANKING) ML_METHOD=$$ml_method ML_PARAMS=\"$$ml_params\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$ml_id >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
				make -s eval DATA_SOURCE=$(DATA_SOURCE) TRAIN_DATA_NAME=train TEST_DATA_NAME=dev   RANKING=$(RANKING) ML_METHOD=$$ml_method ML_PARAMS=\"$$ml_params\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$ml_id >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
				touch $(TTE_DIR)/done.$$ml_id;"; \
		fi; \
		sleep 2; \
	done
	while [ `ls $(TTE_DIR)/done.* 2> /dev/null | wc -l` -lt `cat $(ML_METHOD_LIST) $(RANKING_GREP) | grep -v "^#" | wc -l` ]; do \
		sleep 5; \
	done
	paste $(RESULT_TEMPLATE) $(TTE_DIR)/acc.* >> $@
	#-rm -rf $(TTE_DIR)

tte_feats : $(TTE_FEATS_DIR)/all.acc
	echo -e "DATE:\t$(DATE)" >> $(STATS_FILE)
	cat $< >> $(STATS_FILE)
	cat $(STATS_FILE) | scripts/result_to_html.pl > $(STATS_FILE).html
$(TTE_FEATS_DIR)/all.acc :
	mkdir -p $(TTE_FEATS_DIR)
	mkdir -p $(TTE_FEATS_DIR)/log
	iter=000; \
	for i in `cat $(FEATSET_LIST) | scripts/read_featset_list.pl`; do \
		iter=`perl -e 'my $$x = shift @ARGV; $$x++; printf "%03s", $$x;' $$iter`; \
		feat_list=`echo "$$i" | cut -d"#" -f1`; \
		feat_descr=`echo "$$i" | sed 's/^[^#]*#//' | sed 's/__WS__/ /g'`; \
		featsha=`echo "$$feat_list" | shasum | cut -c 1-10`; \
		qsubmit --jobname="tte_feats.$$featsha" --mem="1g" --priority="0" --logdir="$(TTE_FEATS_DIR)/log/$$featsha" \
			"make -s tte RANKING=$(RANKING) CROSS_VALID_N=$(CROSS_VALID_N) DATA_SOURCE=$(DATA_SOURCE) STATS_FILE=$(TTE_FEATS_DIR)/acc.$$iter.$$featsha DATA_DIR=$(DATA_DIR) TTE_DIR=$(TTE_FEATS_DIR)/$$featsha FEAT_LIST=$$feat_list FEAT_DESCR=\"$$feat_descr\"; \
			touch $(TTE_FEATS_DIR)/done.$$featsha;"; \
		sleep 30; \
	done; \
	featset_count=`cat $(FEATSET_LIST) | scripts/read_featset_list.pl | wc -l`; \
	while [ `ls $(TTE_FEATS_DIR)/done.* 2> /dev/null | wc -l` -lt $$featset_count ]; do \
		sleep 10; \
	done
	cat $(TTE_FEATS_DIR)/acc.* > $@

#--------------------------------- N-fold cross validation -------------------------------------


#			"echo \"$$ml_method $$ml_params\" >> $(TTE_DIR)/acc.$$iter.$$ml_id;"

cross_eval :
	echo "$(ML_METHOD) $(ML_PARAMS)" >> $(STATS_FILE); \
	for (( i=0; i<$(CROSS_VALID_N); i++ )); do \
		cross_ml_id=$(ML_ID).cv_`printf "%02d" $$i`; \
		qsubmit --jobname="tte.$$cross_ml_id" --mem="1g" --priority="0" --logdir="$(TTE_DIR)/log/$$cross_ml_id" \
			"make -s test CROSS_VALID_N=$(CROSS_VALID_N) CROSS_VALID_I=$$i CROSS_VALID_FOLD=out TRAIN_DATA_NAME=train DATA_SOURCE=$(DATA_SOURCE) RANKING=$(RANKING) ML_METHOD=$(ML_METHOD) ML_PARAMS=\"$(ML_PARAMS)\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$cross_ml_id; \
			 make -s test CROSS_VALID_N=$(CROSS_VALID_N) CROSS_VALID_I=$$i CROSS_VALID_FOLD=in  TRAIN_DATA_NAME=train DATA_SOURCE=$(DATA_SOURCE) RANKING=$(RANKING) ML_METHOD=$(ML_METHOD) ML_PARAMS=\"$(ML_PARAMS)\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$cross_ml_id; \
			 touch $(TTE_DIR)/done_cv.$$cross_ml_id;"; \
	done; \
	while [ `ls $(TTE_DIR)/done_cv.$(ML_ID).* 2> /dev/null | wc -l` -lt $(CROSS_VALID_N) ]; do \
		sleep 2; \
	done; \
	cat $(TTE_DIR)/result/train.$(DATA_SOURCE).cv_out_[0-9][0-9].$(ML_ID).res > $(TTE_DIR)/result/train.$(DATA_SOURCE).out.$(ML_ID).res; \
	cat $(TTE_DIR)/result/train.$(DATA_SOURCE).out.$(ML_ID).res | scripts/results_to_triples.pl $(RANK_FLAG) | $(SCRIPT_DIR)/eval.pl $(RANK_EVAL_FLAG) >> $(STATS_FILE); \
	cat $(TTE_DIR)/result/train.$(DATA_SOURCE).cv_in_[0-9][0-9].$(ML_ID).res > $(TTE_DIR)/result/train.$(DATA_SOURCE).in.$(ML_ID).res; \
	cat $(TTE_DIR)/result/train.$(DATA_SOURCE).in.$(ML_ID).res | scripts/results_to_triples.pl $(RANK_FLAG) | $(SCRIPT_DIR)/eval.pl $(RANK_EVAL_FLAG) >> $(STATS_FILE); \
	touch $(TTE_DIR)/done.$(ML_ID)

publish_results_html :
	scp $(STATS_FILE).html mnovak@ufal:/home/mnovak/public_html/data/it_transl_res.html
