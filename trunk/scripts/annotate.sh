#!/usr/bin/env bash
source ${BIOR_ANNOTATE_DIR}/utils/log.sh

usage() {
cat << EOF
##########################################################################################################
##
## Script Options:
##   Required:
##      -c    path to catalog file
##      -d    Path to the drill file
##      -h    Display this help text
##      -l    Enable full log tracing
##      -T    tool info file from GGPS
##      -v    path to the VCF to annotate
## 
## Usage:
##   ./annotate.sh -c <catalog_file> -d <drill_file> -T <tool_info> -v <input_vcf>
##
##########################################################################################################
EOF
}

log="FALSE"

##################################################################################
###
###     Parse Argument variables
###
##################################################################################
log_debug "Options specified: $@"

while getopts "c:d:hlT:v:" OPTION; do
  case $OPTION in
    c)  catalogs=$OPTARG ;;     #
    d)  drills=$OPTARG ;;       #
    h)  usage                   #
        exit ;;
    l)  log="TRUE" ;;
    T)  tool_info=$OPTARG ;;     #
    v)  VCF=$OPTARG ;;           #
    *) log_error "Invalid option: -$OPTARG. See output file for usage." >&2
        usage
        exit ;;
  esac
done

if [ "$log" == "TRUE"  ]
then
	set -x
fi

if [ -z "$tool_info" ]
then
  log_error "A tool_info file is required for annotate.sh."
  exit 100
fi

source $tool_info
source $BIOR_PROFILE
source ${BIOR_ANNOTATE_DIR}/scripts/shared_functions.sh

CWD_VCF=`basename $VCF`
DRILL_FILE=$drills
CATALOG_FILE=$catalogs
let count=0

while read drill
do
  let count=$count+1
  SHORT_NAME=`echo "$drill" | cut -f1 `

  CATALOG=`grep -w "$SHORT_NAME" $CATALOG_FILE|cut -f3|head -1`
  CATALOG_COMMAND=`grep -w "$SHORT_NAME" $CATALOG_FILE|cut -f2|head -1`
  TERMS=`echo "$drill" | cut -f2`
  IFS=',' all_terms=( $TERMS )
  separator=" -p "
  drill_opts="$( printf "${separator}%s" "${all_terms[@]}" )"

  # TODO: can this be replaced by catalog validation function?
  if [ -z "$CATALOG" ]
  then
    log_error "Error parsing CATALOG. Command used: grep -w \"$SHORT_NAME\" $CATALOG_FILE|cut -f3|head -1"
    exit 100
  fi

  if [ -z "$CATALOG_COMMAND" ]
  then
    log_error "Error parsing CATALOG_COMMAND. Command used: grep -w \"$SHORT_NAME\" $CATALOG_FILE|cut -f2|head -1"
    exit 100
  fi

  # TODO: can this be replaced by file_validation utitity?
  if [ ! -s "$VCF" ]
  then
    log_error "$VCF not found. Previous step appears to have failed."
    exit 100
  fi

  cat $VCF | bior_vcf_to_tjson | $CATALOG_COMMAND -d $CATALOG | eval bior_drill ${drill_opts} | bior_tjson_to_vcf > $CWD_VCF.$count

  START_NUM=`cat $VCF | grep -v '^#' | wc -l`
  END_NUM=`cat $CWD_VCF.$count | grep -v '^#' | wc -l`
  if [[ ! -s $CWD_VCF.${count} || ! $END_NUM -ge $START_NUM ]]
  then
    ${BIOR_ANNOTATE_DIR}/scripts/email.sh -f $CWD_VCF.${count} -m annotate.sh -M "bior annotation failed using $CATALOG_FILE" -p $VCF -l $LINENO
    exit 100
  fi

  # Set up for next loop
  if [ "$count" != 1 ]
  then
    let previous=$count-1
    if [[ "$DEBUG_MODE" == "NO" ]]
    then
      rm $VCF
    fi
  fi

  VCF=${CWD_VCF}.${count}
done <$DRILL_FILE
$PERL -pne 's/bior.//g' $CWD_VCF.${count} > ${CWD_VCF}.anno 
