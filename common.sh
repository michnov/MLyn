#!/bin/bash

function run_in_parallel()
{
    cmd=$1
    echo_err $cmd
    lrc=${params[LRC]-1}
    if [ $lrc -eq 1 ]; then
        jobname=$2
        priority=$3
        logdir=$4
        timeout=$5
        ./log.sh INFO "Running job $jobname on cluster. The logfile can be found in $logdir"
        qsubmit --jobname="$jobname" --mem="1g" --priority="$priority" --logdir="$logdir" \
            "$cmd"
        sleep $timeout
    else
        eval $cmd
    fi
}

function echo_err() {
    echo "$@" >&2
}

function print_ranking_header() {
    if [ -z $1 ]; then
        echo "TRAIN:"
    else
        echo "$1:"
    fi
    echo
    echo
    echo
}
