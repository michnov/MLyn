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

    $ML_FRAMEWORK_DIR/log.sh DEBUG "Loading parameters..."

   
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
    $ML_FRAMEWORK_DIR/log.sh DEBUG "Saving parameters into $output_file"
    if [ -f $output_file ]; then
        rm $output_file;
    fi
    all_keys=`eval 'echo ${!'$config_var'[@]}'`
    for key in $all_keys; do
        value=`eval 'echo "${'$config_var'['$key']}"'`
        echo $key=$value >> $output_file
    done
}

function prepare_run_dir() 
{
    if [ -z ${params[DATE]} ]; then
        params[DATE]=`date +%Y-%m-%d_%H-%M-%S`
    fi
    $ML_FRAMEWORK_DIR/log.sh DEBUG "DATE = "${params[DATE]}
    if [ -z ${params[RUN_DIR]} ]; then
        run_num=`ls ${params[TMP_DIR]} | grep "^[0-9]\{3\}_" | sort | tail -n1 | perl -we 'my ($l) = split /_/, <STDIN>; $l++; printf "%03d\n", $l;'`
        run_base_dir="$run_num"_run_${params[DATE]}_$$
        if [ ! -z "${params[D]}" ]; then
            descr=`echo ${params[D]} | sed 's/[ \t]\+/_/g'`
            run_base_dir="$run_base_dir".$descr
            $ML_FRAMEWORK_DIR/log.sh DEBUG "TMP_DIR: $run_base_dir"
        fi
        if [ ! -z ${params[TMP_DIR]} ]; then
            params[RUN_DIR]=${params[TMP_DIR]}/$run_base_dir
        else
            params[RUN_DIR]=$run_base_dir
        fi
    fi
    mkdir -p ${params[RUN_DIR]}
}

declare -A params
load_params params "$@"
