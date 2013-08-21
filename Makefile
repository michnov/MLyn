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

#--------------------------------------- PREPARE DATA ----------------------------------------------------------

extract_data : $(DATA_DIR)/train.$(DATA_ID).idx.table $(DATA_DIR)/dev.$(DATA_ID).idx.table

$(DATA_DIR)/%.$(DATA_ID).idx.table : $(DATA_DIR)/%.$(DATA_ID).table
	zcat $< | \
	$(SCRIPT_DIR)/index_class.pl $(DATA_DIR)/train.$(DATA_ID).idx | \
	gzip -c > $@

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
		'hash=`date | shasum | cut -c 1-5`; \
		zcat $< | $(SCRIPT_DIR)/filter_feat.pl --in $(FEAT_LIST) | scripts/vw_convert.pl | gzip -c > /COMP.TMP/train.$(DATA_ID).idx.vw.table.$$hash; \
		$(VW_APP) -d /COMP.TMP/train.$(DATA_ID).idx.vw.table.$$hash -f $@ --sequence_max_length 10000 --compressed \
			--oaa `zcat $< | cut -f 1 | sort -n | tail -n1` $(ML_PARAMS) \
			-c -k --cache_file /COMP.TMP/train.$(DATA_ID).idx.vw.cache.$$hash; \
		rm /COMP.TMP/train.$(DATA_ID).idx.vw.table.$$hash; \
		rm /COMP.TMP/train.$(DATA_ID).idx.vw.cache.$$hash' $@
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
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/maxent.test.pl $< > $@' $@
$(RESULT_DIR)/%.$(DATA_ID).vw.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).vw.$(ML_PARAMS_HASH).model $(DATA_DIR)/%.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) \
		'hash=`date | shasum | cut -c 1-5`; \
		zcat $(word 2,$^) | scripts/vw_convert.pl --test | gzip -c > /COMP.TMP/$*.$(DATA_ID).idx.vw.table.$$hash; \
		zcat /COMP.TMP/$*.$(DATA_ID).idx.vw.table.$$hash | $(VW_APP) -t -i $< -p /COMP.TMP/$*.$(DATA_ID).vw.res.tmp.$$hash --sequence_max_length 10000; \
		rm /COMP.TMP/$*.$(DATA_ID).idx.vw.table.$$hash; \
		perl -pe '\''$$_ =~ s/^(.*?)\..*? (.*?)$$/$$2\t$$1/;'\'' < /COMP.TMP/$*.$(DATA_ID).vw.res.tmp.$$hash > $@; \
		rm /COMP.TMP/$*.$(DATA_ID).vw.res.tmp.$$hash' $@

$(RESULT_DIR)/train.$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model $(DATA_DIR)/train.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/sklearn.test.py $< > $@' $@
$(RESULT_DIR)/dev.$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model $(DATA_DIR)/dev.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/sklearn.test.py $< > $@' $@
$(RESULT_DIR)/eval.$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).res : $(MODEL_DIR)/$(DATA_ID).sklearn.%.$(ML_PARAMS_HASH).model $(DATA_DIR)/eval.$(DATA_ID).idx.table
	$(TEST_QSUBMIT) 'zcat $(word 2,$^) | $(SCRIPT_DIR)/sklearn.test.py $< > $@' $@

clean_test:
	-rm $(RESULT_DIR)/*.$(DATA_ID).$(ML_ID).res

#----------------------------------------- EVAL --------------------------------------------------------------

eval : eval_dev
eval_% : $(RESULT_DIR)/%.$(DATA_ID).$(ML_ID).res
	$(SCRIPT_DIR)/eval.pl < $<

#---------------------------------------- CLEAN -------------------------------------------------------

clean : clean_test clean_train

#======================================== ML SCENARIOS ==============================================================

#RUNS_DIR=tmp
CONF_DIR=conf

STATS_FILE=results
ML_METHOD_LIST=$(CONF_DIR)/ml_methods
FEATSET_LIST=$(CONF_DIR)/featset_list
RESULT_TEMPLATE=$(CONF_DIR)/result.template


#--------------------------------- train, test, eval for all metnods -------------------------------------

TTE_DIR=$(RUNS_DIR)/tte_$(DATE)
TTE_FEATS_DIR=$(RUNS_DIR)/tte_feats_$(DATE)

tte : $(TTE_DIR)/all.acc
	cat $< >> $(STATS_FILE)
$(TTE_DIR)/all.acc :
	mkdir -p $(TTE_DIR)
	mkdir -p $(TTE_DIR)/log
	mkdir -p $(TTE_DIR)/model
	mkdir -p $(TTE_DIR)/result
	echo "FEATS:\t$(FEAT_LIST)" | sed 's/,/, /g' >> $@; \
	echo -n "INFO:\t" >> $@; \
	echo -n "$(DATE)\t$(DATA_ID)\t`git rev-parse --abbrev-ref HEAD`:`git rev-parse HEAD | cut -c 1-10`" >> $@; \
	echo -n "\t`zcat $(DATA_DIR)/train.$(DATA_ID).table | cut -f1 | sort | shasum | cut -c 1-10`\t" >> $@; \
	echo $(FEAT_LIST) | shasum | cut -c 1-10 >> $@;
	iter=000; \
	cat $(ML_METHOD_LIST) | while read i ; do \
		if [ `echo $$i | cut -c1` = "#" ]; then \
			continue; \
		fi; \
		iter=`perl -e 'my $$x = shift @ARGV; $$x++; printf "%03s", $$x;' $$iter`; \
		ml_method=`echo $$i | cut -f1 -d':'`; \
		ml_params="`echo $$i | cut -f2 -d':'`"; \
		echo "$$ml_params"; \
		ml_params_hash=`echo "$$ml_params" | shasum | cut -c 1-5`; \
		ml_id=$$ml_method.$$ml_params_hash; \
		mkdir -p $(TTE_DIR)/log/$$ml_id; \
		qsubmit --jobname="tte.$$ml_id" --mem="1g" --priority="0" --logdir="$(TTE_DIR)/log/$$ml_id" \
			"echo \"$$ml_method $$ml_params\" >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
			make -s eval_train DATA_ID=$(DATA_ID) ML_METHOD=$$ml_method ML_PARAMS=\"$$ml_params\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$ml_id >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
			make -s eval_dev DATA_ID=$(DATA_ID) ML_METHOD=$$ml_method ML_PARAMS=\"$$ml_params\" FEAT_LIST=$(FEAT_LIST) DATA_DIR=$(DATA_DIR) MODEL_DIR=$(TTE_DIR)/model RESULT_DIR=$(TTE_DIR)/result QSUB_LOG_DIR=$(TTE_DIR)/log/$$ml_id >> $(TTE_DIR)/acc.$$iter.$$ml_id; \
			touch $(TTE_DIR)/done.$$ml_id;"; \
		sleep 2; \
	done
	while [ `ls $(TTE_DIR)/done.* 2> /dev/null | wc -l` -lt `cat $(ML_METHOD_LIST) | wc -l` ]; do \
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
	for i in `cat $(FEATSET_LIST)`; do \
		if [ `echo $$i | cut -c1` = "#" ]; then \
			continue; \
		fi; \
		iter=`perl -e 'my $$x = shift @ARGV; $$x++; printf "%03s", $$x;' $$iter`; \
		featsha=`echo "$$i" | shasum | cut -c 1-10`; \
		qsubmit --jobname="tte_feats.$$featsha" --mem="1g" --priority="0" --logdir="$(TTE_FEATS_DIR)/log/$$featsha" \
			"make -s tte DATA_ID=$(DATA_ID) STATS_FILE=$(TTE_FEATS_DIR)/acc.$$iter.$$featsha DATA_DIR=$(DATA_DIR) TTE_DIR=$(TTE_FEATS_DIR)/$$featsha FEAT_LIST=$$i; \
			touch $(TTE_FEATS_DIR)/done.$$featsha;"; \
		sleep 30; \
	done
	while [ `ls $(TTE_FEATS_DIR)/done.* 2> /dev/null | wc -l` -lt `cat $(FEATSET_LIST) | grep -v "^#" | wc -l` ]; do \
		sleep 10; \
	done
	cat $(TTE_FEATS_DIR)/acc.* > $@

publish_results_html :
	scp $(STATS_FILE).html mnovak@ufal:/home/mnovak/public_html/data/it_transl_res.html
