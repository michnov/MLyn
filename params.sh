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

    local OPTIND
    while getopts ":f:" opt; do
        case $opt in
            f) config_file=$OPTARG
                ;;
            \?) echo "Invalid option: -$OPTARG" >&2
                ;;
        esac
    done

    ./log.sh DEBUG "Loading parameters..."

   
    # this should disregard all lines starting with #
    # and all parameters without a value in the "name=" format

    sed_cmd='s/^\([^=]*\)=\(.*\)$/'$config_var'[\1]="\2";/'
    config_script=`cat $config_file | grep -v "^#" | sed $sed_cmd`
    shift $(($OPTIND - 1))
    
    config_script+=`perl -e '$out = join " ", map {$_ =~ s/ /__SPACE__/g; $_} @ARGV; print $out;' "$@" |\
        sed 's/ /\n/g' | sed 's/__SPACE__/ /g' | sed $sed_cmd`

    eval $config_script
    
    all_keys=`eval 'echo ${!'$config_var'[@]}'`
    for key in $all_keys; do
        value=`eval 'echo ${'$config_var'['$key']}'`
        if [ -z "$value" ]; then
            eval 'unset '$config_var'['$key']'
        fi
    done
}

function save_params()
{
    config_var=$1
    output_file=$2
    ./log.sh DEBUG "Saving parameters into $output_file"
    if [ -f $output_file ]; then
        rm $output_file;
    fi
    all_keys=`eval 'echo ${!'$config_var'[@]}'`
    for key in $all_keys; do
        value=`eval 'echo ${'$config_var'['$key']}'`
        echo $key=$value >> $output_file
    done
}

declare -A params
load_params params "$@"
mkdir -p ${params[RUN_DIR]}
save_params params ${params[RUN_DIR]}/config
