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
