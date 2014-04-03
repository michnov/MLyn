LRC=1
JOBS_NUM=100

ifeq ($(LRC),1)
LRC_FLAGS=-p --qsub '-hard -l mem_free=6G -l act_mem_free=6G -l h_vmem=6G' --jobs ${JOBS_NUM}
endif

DATE := $(shell date +%Y-%m-%d_%H-%M-%S)

SCRIPT_DIR=scripts

#DATA_DIR=data
#MODEL_DIR=model
#RESULT_DIR=result
#LOG_DIR=log
#QSUB_LOG_DIR=$(LOG_DIR)/qsubmit

DATA_ID=pcedt
#DATA_ID=czeng

RANKING=0

#--------------------------------------- PREPARE DATA ----------------------------------------------------------

extract_data : $(DATA_DIR)/train.$(DATA_ID).idx.table $(DATA_DIR)/dev.$(DATA_ID).idx.table

$(DATA_DIR)/%.$(DATA_ID).idx.table : $(DATA_DIR)/%.$(DATA_ID).table
	if [ $(RANKING) -eq 0 ]; then \
		zcat $< | \
			$(SCRIPT_DIR)/index_class.pl $(DATA_DIR)/train.$(DATA_ID).idx | \
			gzip -c > $@; \
	else \
		cp $< $@; \
	fi

.SECONDARY : $(DATA_DIR)/train.$(DATA_ID).table $(DATA_DIR)/dev.$(DATA_ID).table $(DATA_DIR)/eval.$(DATA_ID).table

clean_data :
	-rm $(DATA_DIR)/*.$(DATA_ID).idx*

#----------------------------------------- TRAIN --------------------------------------------------------------

ML_METHOD=maxent
#ML_METHOD=vw
#ML_METHOD=sklearn.decision_trees

ifeq ($(ML_METHOD),vw)
ML_PARAMS=--passes 20
endif

ML_PARAMS_HASH = $(shell echo "$(ML_PARAMS)" | shasum | cut -c 1-5)
ML_ID=$(ML_METHOD).$(ML_PARAMS_HASH)

TRAIN_QSUBMIT=$(SCRIPT_DIR)/qsubmit_sleep --jobname="train.$(ML_ID).$(DATA_ID)" --mem="15g" --priority="0" --logdir="$(QSUB_LOG_DIR)" --sync

VW_APP=/net/work/people/mnovak/tools/x86_64/vowpal_wabbit/vowpalwabbit/vw

train : $(MODEL_DIR)/$(DATA_ID).$(ML_ID).model

$(MODEL_DIR)/$(DATA_ID).maxent.$(ML_PARAMS_HASH).model : $(DATA_DIR)/train.$(DATA_ID).idx.table
	$(TRAIN_QSUBMIT) 'zcat $< | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/maxent.train.pl $@' $@
$(MODEL_DIR)/$(DATA_ID).vw.$(ML_PARAMS_HASH).model : $(DATA_DIR)/train.$(DATA_ID).idx.table
	$(TRAIN_QSUBMIT) \
		'zcat $< | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl | gzip -c > /COMP.TMP/train.$(DATA_ID).idx.vw.table.$$$$; \
		$(VW_APP) -d /COMP.TMP/train.$(DATA_ID).idx.vw.table.$$$$ -f $@ --sequence_max_length 10000 --compressed \
			--oaa `zcat $< | cut -f 1 | sort -n | tail -n1` $(ML_PARAMS) \
			-c -k --cache_file /COMP.TMP/train.$(DATA_ID).idx.vw.cache.$$$$; \
		rm /COMP.TMP/train.$(DATA_ID).idx.vw.table.$$$$; \
		rm /COMP.TMP/train.$(DATA_ID).idx.vw.cache.$$$$' $@
$(MODEL_DIR)/$(DATA_ID).vw.ranking.$(ML_PARAMS_HASH).model : $(DATA_DIR)/train.$(DATA_ID).idx.table
	$(TRAIN_QSUBMIT) \
		'zcat $< | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl -m | gzip -c > /COMP.TMP/train.$(DATA_ID).idx.vw.ranking.table.$$$$; \
		$(VW_APP) -d /COMP.TMP/train.$(DATA_ID).idx.vw.ranking.table.$$$$ -f $@ --sequence_max_length 10000 --compressed \
			--csoaa_ldf m $(ML_PARAMS) \
			-c -k --cache_file /COMP.TMP/train.$(DATA_ID).idx.vw.ranking.cache.$$$$; \
		rm /COMP.TMP/train.$(DATA_ID).idx.vw.ranking.table.$$$$; \
		rm /COMP.TMP/train.$(DATA_ID).idx.vw.ranking.cache.$$$$' $@
$(MODEL_DIR)/$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model : $(DATA_DIR)/train.$(DATA_ID).idx.table
	$(TRAIN_QSUBMIT) 'zcat $< | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/sklearn.train.py $* "$(ML_PARAMS)" $@' $@

clean_train:
	-rm $(MODEL_DIR)/$(DATA_ID).$(ML_ID).model

#----------------------------------------- TEST --------------------------------------------------------------

TEST_QSUBMIT=$(SCRIPT_DIR)/qsubmit_sleep  --jobname="test.$(ML_ID).$(DATA_ID)" --mem="15g" --priority="0" --logdir="$(QSUB_LOG_DIR)" --sync

test : test_dev
test_dev : $(RESULT_DIR)/dev.$(DATA_ID).$(ML_ID).res
test_train : $(RESULT_DIR)/train.$(DATA_ID).$(ML_ID).res

$(RESULT_DIR)/%.$(DATA_ID).maxent.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).maxent.$(ML_PARAMS_HASH).model $(DATA_DIR)/%.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/maxent.test.pl $< > $@' $@
$(RESULT_DIR)/%.$(DATA_ID).vw.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).vw.$(ML_PARAMS_HASH).model $(DATA_DIR)/%.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) \
		'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl --test | gzip -c > /COMP.TMP/$*.$(DATA_ID).idx.vw.table.$$$$; \
		zcat /COMP.TMP/$*.$(DATA_ID).idx.vw.table.$$$$ | $(VW_APP) -t -i $< -p /COMP.TMP/$*.$(DATA_ID).vw.res.tmp.$$$$ --sequence_max_length 10000; \
		rm /COMP.TMP/$*.$(DATA_ID).idx.vw.table.$$$$; \
		perl -pe '\''$$_ =~ s/^(.*?)\..*? (.*?)$$/$$2\t$$1/;'\'' < /COMP.TMP/$*.$(DATA_ID).vw.res.tmp.$$$$ > $@; \
		rm /COMP.TMP/$*.$(DATA_ID).vw.res.tmp.$$$$' $@
$(RESULT_DIR)/%.$(DATA_ID).vw.ranking.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).vw.ranking.$(ML_PARAMS_HASH).model $(DATA_DIR)/%.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) \
		'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl -m | gzip -c > /COMP.TMP/$*.$(DATA_ID).idx.vw.ranking.table.$$$$; \
		zcat /COMP.TMP/$*.$(DATA_ID).idx.vw.ranking.table.$$$$ | $(VW_APP) -t -i $< -p $@ --sequence_max_length 10000; \
		rm /COMP.TMP/$*.$(DATA_ID).idx.vw.ranking.table.$$$$' $@
$(RESULT_DIR)/train.$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model $(DATA_DIR)/train.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/sklearn.test.py $< > $@' $@
$(RESULT_DIR)/dev.$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model $(DATA_DIR)/dev.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/sklearn.test.py $< > $@' $@
$(RESULT_DIR)/eval.$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model $(DATA_DIR)/eval.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | $(SCRIPT_DIR)/sklearn.test.py $< > $@' $@

clean_test:
	-rm $(RESULT_DIR)/*.$(DATA_ID).$(ML_ID).res

		#inst_num=`grep "^$$" $@ | wc -l`; \
		#if ["$$inst_num" -ne 1988 -a "$$inst_num" -ne 19294]; then \
		#	cp /COMP.TMP/$*.$(DATA_ID).idx.vw.ranking.table.$$$$ $(QSUB_LOG_DIR)/$*.$(DATA_ID).idx.vw.ranking.table.$$$$.$$$$; \
		#fi; 
#----------------------------------------- EVAL --------------------------------------------------------------

ifeq ($(RANKING),1)
RANK_FLAG=--ranking
RANK_EVAL_FLAG=--acc --prf
endif

eval : eval_dev
eval_% : $(RESULT_DIR)/%.$(DATA_ID).$(ML_ID).res
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
	echo "$(DATA_DIR)/train.$(DATA_ID).table"
	echo "FEATS:\t$(FEAT_DESCR)" >> $@; \
	echo -n "INFO:\t" >> $@; \
	echo -n "$(DATE)\t$(DATA_ID)\t`git rev-parse --abbrev-ref HEAD`:`git rev-parse HEAD | cut -c 1-10`" >> $@; \
	echo -n "\t`zcat $(DATA_DIR)/train.$(DATA_ID).table | cut -f1 | sort | shasum | cut -c 1-10`\t" >> $@; \
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
		qsubmit --jobname="tte.$$ml_id" --mem="1g" --priority="0" --logdir="$(TTE_DIR)/log/$$ml_id" \
			"echo \"$$ml_method $$ml_params\" >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
			make -s eval_train RANKING=$(RANKING) DATA_ID=$(DATA_ID) ML_METHOD=$$ml_method ML_PARAMS=\"$$ml_params\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$ml_id >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
			make -s eval_dev RANKING=$(RANKING) DATA_ID=$(DATA_ID) ML_METHOD=$$ml_method ML_PARAMS=\"$$ml_params\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$ml_id >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
			touch $(TTE_DIR)/done.$$ml_id;"; \
		sleep 2; \
	done
	while [ `ls $(TTE_DIR)/done.* 2> /dev/null | wc -l` -lt `cat $(ML_METHOD_LIST) $(RANKING_GREP) | grep -v "^#" | wc -l` ]; do \
		sleep 5; \
	done
	paste $(RESULT_TEMPLATE) $(TTE_DIR)/acc.* >> $@
	#-rm -rf $(TTE_DIR)

tte_feats : $(TTE_FEATS_DIR)/all.acc
	echo "DATE:\t$(DATE)" >> $(STATS_FILE)
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
			"make -s tte RANKING=$(RANKING) DATA_ID=$(DATA_ID) STATS_FILE=$(TTE_FEATS_DIR)/acc.$$iter.$$featsha DATA_DIR=$(DATA_DIR) TTE_DIR=$(TTE_FEATS_DIR)/$$featsha FEAT_LIST=$$feat_list FEAT_DESCR=\"$$feat_descr\"; \
			touch $(TTE_FEATS_DIR)/done.$$featsha;"; \
		sleep 30; \
	done; \
	featset_count=`cat $(FEATSET_LIST) | scripts/read_featset_list.pl | wc -l`; \
	while [ `ls $(TTE_FEATS_DIR)/done.* 2> /dev/null | wc -l` -lt $$featset_count ]; do \
		sleep 10; \
	done
	cat $(TTE_FEATS_DIR)/acc.* > $@

publish_results_html :
	scp $(STATS_FILE).html mnovak@ufal:/home/mnovak/public_html/data/it_transl_res.html
