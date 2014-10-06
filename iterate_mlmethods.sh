#!/bin/bash

source common.sh

function iterate_mlmethods()
{
    featset=${params[featset]}
    mlmethod_list=${params[mlmethod_list]}
    run_dir=${params[run_dir]}

	iter=000
    cat $mlmethod_list | grep -v "^#" > $run_dir/mlmethod_per_line.list

    # run an experiment for every feature set
	cat $run_dir/mlmethod_per_line.list | while read mlmethod; do
		iter=`perl -e 'my $x = shift @ARGV; $x++; printf "%03s", $x;' $iter`
		feats=`echo "$i" | cut -d"#" -f1`
		feats_descr=`echo "$i" | sed 's/^[^#]*#//' | sed 's/__WS__/ /g'`
		featsha=`echo "$feats" | shasum | cut -c 1-10`

        run_subdir=$run_dir/$iter.$featsha.featset
        mkdir -p $run_subdir

        feats_info_file=$run_subdir/info
	    echo -en "FEATS:" >> $feats_info_file
	    echo -en "\t$feats_descr" >> $feats_info_file
	    echo -en "\t$featsha" >> $feats_info_file
	    echo -e "\t`echo $feats | sed 's/,/, /g'`" >> $feats_info_file

        run_in_parallel \
            "echo ahoj" \
            "featset_exper.$featsha" -50 $run_subdir/log 30
            
            # TODO
			#"make -s tte SEMI_SUP=$(SEMI_SUP) DATA_SOURCE_1=$(DATA_SOURCE_1) DATA_SOURCE_2=$(DATA_SOURCE_2) DATA_DIR_1=$(DATA_DIR_1) DATA_DIR_2=$(DATA_DIR_2) RANKING=$(RANKING) CROSS_VALID_N=$(CROSS_VALID_N) TRAIN_DATA_NAME=$(TRAIN_DATA_NAME) TEST_DATA_NAME=$(TEST_DATA_NAME) DATA_SOURCE=$(DATA_SOURCE) STATS_FILE=$(TTE_FEATS_DIR)/acc.$$iter.$$featsha DATA_DIR=$(DATA_DIR) TTE_DIR=$(TTE_FEATS_DIR)/$$featsha FEAT_LIST=$$feat_list FEAT_DESCR=\"$$feat_descr\"; \
			#touch $(TTE_FEATS_DIR)/done.$$featsha;";
	done
    
    # wait until all experiments are acomplished
	featset_count=`cat $run_dir/featset_per_line.list | wc -l`
	while [ `ls $run_dir/*.featset/done 2> /dev/null | wc -l` -lt $featset_count ]; do
		sleep 10
	done

    # collect results
    stats=$run_dir/stats
    for run_subdir in $run_dir/*.featset; do
        cat $run_subdir/info >> $stats
        # TODO
	    cat $(TTE_FEATS_DIR)/acc.* > $@
    done

}


