#!/bin/bash

source $ML_FRAMEWORK_DIR/params.sh

function filter_feats() {
    from_path=$1
    to_path=$2
    feat_list=$3

	if [ -n "$feat_list" ]; then
		$ML_FRAMEWORK_DIR/log.sh INFO "Feature filtering: $from_path => $to_path"
        echo "zcat $from_path | $ML_FRAMEWORK_DIR/scripts/filter_feat.pl --in $feat_list | gzip -c > $to_path"
		zcat $from_path | $ML_FRAMEWORK_DIR/scripts/filter_feat.pl --in "$feat_list" | gzip -c > $to_path
	else
		$ML_FRAMEWORK_DIR/log.sh INFO "Symlinking a data file: $from_path -> $to_path"
        from_path_abs=`readlink -f $from_path`
		ln -s $from_path_abs $to_path
		if ! cat $to_path > /dev/null 2>&1; then
			$ML_FRAMEWORK_DIR/log.sh WARN "Too many symlinks for $from_path_abs. Copying instead: $from_path_abs => $to_path"
			rm $to_path
			cp $from_path_abs $to_path
		fi
	fi
}

filter_feats ${params[IN_FILE]} ${params[OUT_FILE]} "${params[FEAT_LIST]}"
