#!/bin/bash

# loading parameters into a global hash
# parameters can be specified both in a file: argument -f <file>
# or directly as a commmand arg
# the format of parameters is: name=value
# INPUT:
#   1) the name of a global hash
#   2) all arguments passed in a command
function load_params()
{
    config_var=$1
    shift
    echo "$@"

    local OPTIND
    while getopts ":f:" opt; do
        case $opt in
            f) config_file=$OPTARG
                ;;
            \?) echo "Invalid option: -$OPTARG" >&2
                ;;
        esac
    done

    sed_cmd='s/^\([^=]*\)=\(.*\)$/'$config_var'[\1]=\2;/'
    config_script=`cat $config_file | sed $sed_cmd`
    shift $(($OPTIND - 1))
    
    config_script+=`echo "$@" | sed 's/ /\n/g' | sed $sed_cmd`
    eval $config_script
}

function save_params()
{
    config_var=$1
    output_file=$2
    all_keys=`eval 'echo ${!'$config_var'[@]}'`
    for key in $all_keys; do
        value=`eval 'echo ${'$config_var'['$key']}'`
        echo $key=$value >> $output_file
    done
}

function run_in_parallel()
{
    cmd=$1
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

#declare -A params
#load_params params "$@"
#echo "POzdrav: ${params[file]}"
#echo "Blbost: ${params[skuska]}"
#echo "ROBO: ${params[ROBO]}"
#echo "FUCK: ${params[FUCK]}"
