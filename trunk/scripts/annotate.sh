#!/usr/bin/env bash

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
while getopts "c:d:hlT:v:" OPTION; do
  case $OPTION in
    c)  catalogs=$OPTARG ;;     #
    d)  drills=$OPTARG ;;       #
    h)  usage                   #
        exit ;;
    l)  log="TRUE" ;;
    T)  tool_info=$OPTARG ;;     #
    v)  VCF=$OPTARG ;;           #
    *) echo "Invalid option: -$OPTARG. See output file for usage." >&2
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
  echo "A tool_info file is required for annotate.sh."
  exit 100
fi

source $tool_info
# source $BIOR_PROFILE
# Add BIOR bin to path  (NOTE: The variable $BIOR includes the ./bin subdir)
export PATH=$BIOR:$PATH
export BIOR_LITE_HOME=`dirname $BIOR`

source "${BIOR_ANNOTATE_DIR}/utils/log.sh"
source "${BIOR_ANNOTATE_DIR}/scripts/shared_functions.sh"

log_debug "Options specified: $@"

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

  ###-------------------------------------------------------------------------------------
  ### Annotate the VCF...
  ###-------------------------------------------------------------------------------------
  

  ##-----------------------------------------------
  ## MIKE - Remove the bior_vcf_to_tjson and bior_tjson_to_vcf cmds after each step - only do at beginning and end
  ## If this is the first file in the process, then run bior_vcf_to_tjson on it
  ##-----------------------------------------------
  # If it's the first file, then use bior_vcf_to_tjson, else just cat the file again (straight pass-thru)
  VCF_TO_TJSON="${BIOR}/bior_vcf_to_tjson -lf $CWD_VCF.$count.vcfToTjson.log"
  if [ "$count" != 1 ] ; then
    VCF_TO_TJSON="cat"
  fi

  # Since we've stripped off columns after 8, the bior_vcf_to_tjson should add JSON to column 9
  VCF_JSON_COL=9
  cmd="cat $VCF | eval $VCF_TO_TJSON | ${BIOR}/$CATALOG_COMMAND -d $CATALOG -l  -c $VCF_JSON_COL | eval ${BIOR}/bior_drill ${drill_opts}  > $CWD_VCF.$count"
  eval ${cmd}


  START_NUM=`cat $VCF | grep -v '^#' | wc -l`
  END_NUM=`cat $CWD_VCF.$count | grep -v '^#' | wc -l`
  if [[ ! -s $CWD_VCF.${count} || ! $END_NUM -ge $START_NUM ]]
  then
    log_error "Attempted to execute: $cmd"
    log_error "`which java`"
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

## Strip out any "bior." prefixes, pass thru bior_tjson_to_vcf
$PERL -pne 's/bior.//g' $CWD_VCF.${count} |  bior_tjson_to_vcf -lf ${CWD_VCF}.tjsonToVcf.log > ${CWD_VCF}.anno 
check_file ${CWD_VCF}.anno
