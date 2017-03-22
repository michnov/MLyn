#!/bin/bash

# INPUT:
#   1) RUN_DIR - a directory to store all intermediate files in
#   2) FEATSET_LIST - a path to the list of feature sets to run experiments with
# OUTPUT:
#   RUN_DIR/stats


# the associative array "params" is global
# the "config_file" constant is global
function iterate_featsets()
{

    $ML_FRAMEWORK_DIR/log.sh INFO "Running $0..."

#source $ML_FRAMEWORK_DIR/common.sh
#source $ML_FRAMEWORK_DIR/params.sh

#config_file=${params[RUN_DIR]}/config

    ###################################

    featset_list=${params[FEATSET_LIST]}
    run_dir=${params[RUN_DIR]}

    $ML_FRAMEWORK_DIR/log.sh DEBUG "Processing the featset list: $featset_list => $run_dir/featset_per_line.list"
    cat $featset_list | $ML_FRAMEWORK_DIR/scripts/read_featset_list.pl > $run_dir/featset_per_line.list

    iter=000
    # run an experiment for every feature set
    cat $run_dir/featset_per_line.list | while read featset; do
        iter=`perl -e 'my $x = shift @ARGV; $x++; printf "%03s", $x;' $iter`
        
        feats=`echo "$featset" | cut -d"#" -f1`
        feats_descr=`echo "$featset" | sed 's/^[^#]*#//' | sed 's/__WS__/ /g'`
        feats_sha=`echo "$feats" | shasum | cut -c 1-10`

        run_subdir=$run_dir/$iter.$feats_sha.featset
        mkdir -p $run_subdir

        # print out an info file
        feats_info_file=$run_subdir/info
        echo -en "FEATS:" >> $feats_info_file
        echo -en "\t$feats_descr" >> $feats_info_file
        echo -en "\t$feats_sha" >> $feats_info_file
        echo -e "\t`echo $feats | sed 's/,/, /g'`" >> $feats_info_file
        
        $ML_FRAMEWORK_DIR/log.sh INFO "Running an experiment no. $iter using the featset with sha $feats_sha"
        $ML_FRAMEWORK_DIR/log.sh DEBUG "Its running directory is: $run_subdir"

        run_in_parallel \
            "$ML_FRAMEWORK_DIR/run_experiment.sh \
                -f $config_file \
                FEATSET_LIST= \
                FEAT_LIST=$feats \
                RUN_DIR=$run_subdir; \
             touch $run_subdir/done;" \
            "featset_exper.$feats_sha" -50 $run_subdir/log 30
    done

    # wait until all experiments are acomplished
    featset_count=`cat $run_dir/featset_per_line.list | wc -l`
    wait_for_jobs "$run_dir/*.featset/done" $featset_count

    # collect results
    stats=$run_dir/stats
    $ML_FRAMEWORK_DIR/log.sh INFO "Collecting results of the experiments to: $stats"
    for run_subdir in $run_dir/*.featset; do
        cat $run_subdir/info >> $stats
        cat $run_subdir/stats >> $stats
    done
    
    # find best model
    cat $run_dir/*.featset/best.model | sort -k1,1 -n | tail -n1 > $run_dir/best.model
}

function run_on_featset {
    
    $ML_FRAMEWORK_DIR/log.sh INFO "Filtering features in the data used in the experiments..."

    # feat_list and data_list should be defined in the config file
    # unless feat_list is defined, the original full data is symlinked
    
    #feat_list=${1-${params[FEAT_LIST]}}
    data_list=${params[DATA_LIST]:-"TRAIN_DATA TEST_DATA"}
    $ML_FRAMEWORK_DIR/log.sh DEBUG "DATA_LIST: $data_list"

    tmp_dir=${params[RUN_DIR]}/data
    data_dir=$tmp_dir/processed
    mkdir -p $data_dir

    i=0
    for data_name in $data_list; do
        data=${params[$data_name]}
        
        for orig_file in $data; do
            filt_file=`preprocessed_file_name $orig_file $data_dir`

            if [ ! -e $orig_file ]; then
                $ML_FRAMEWORK_DIR/log.sh WARN "File $filt_file does not exist."
            
            # preprocess only if the result doesn't exist or is older
            elif [ $filt_file -ot $orig_file ]; then
                $ML_FRAMEWORK_DIR/log.sh INFO "Preprocessing data: $orig_file => $filt_file"
                iter=`printf "%03d" $i`
                run_in_parallel \
                    "$ML_FRAMEWORK_DIR/preprocess.sh \
                        -f $config_file \
                        IN_FILE=$orig_file \
                        OUT_FILE=$filt_file; \
                     touch $tmp_dir/$iter.done;" \
                    "preproc.$iter" 0 $tmp_dir/log 0
                ((i++))
            fi
        done
        params[$data_name]=`preprocessed_file_name "$data" $data_dir` 
    done
        
    # wait until all experiments are acomplished
    wait_for_jobs "$tmp_dir/*.done" $i

    unset params[FEAT_LIST]
    
    ## TODO: I don't know why this unset was here - probably due to semi-supervised learning???
    ## but if it's here, DATA_LIST as a default value of TEST_DATA_LIST does not work
    #unset params[DATA_LIST]

    save_params params $config_file
}

function preprocessed_file_name() {
    ( set -f
      for f in $1; do
          file_stem=`$ML_FRAMEWORK_DIR/scripts/file_stem.pl --multi-out "$f"`
          filt_file=$2/$file_stem.table
          echo "$filt_file"
      done
    )
}
