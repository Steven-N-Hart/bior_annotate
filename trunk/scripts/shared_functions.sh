#! /usr/bin/env bash

source ${BIOR_ANNOTATE_DIR}/utils/log.sh

# to check and validate the input bam file
function validate_bam()	{
	samtools=$1
	bamfile_1=$2
	dir=$3
	rand=$RANDOM
	rand1=$RANDOM
	if [ ! -s $2 ]
	then
		echo -e "$bamfile : doesn't exist"
		exit 1;
	fi	
	bam_name=`basename $bamfile_1`
	if [ "$SGE_TASK_ID" ]
	then
		tag="$rand.$rand1.$SGE_TASK_ID"
	else
		tag="$rand.$rand1"
	fi	
	$samtools/samtools view -H $bamfile_1 1>$dir/$bam_name.$tag.header 2> $dir/$bam_name.$tag.log
	if [[ `cat $dir/$bam_name.$tag.log | wc -l` -gt 0 || `cat $dir/$bam_name.$tag.header | wc -l` -le 0 ]]
	then
		echo -e "\n************************************"
		echo -e "ERROR : $bamfile_1 file is truncated or corrupted [`date`]"
		echo -e "\n************************************"
		exit 1;
	else
		rm $dir/$bam_name.$tag.log
	fi	
	rm $dir/$bam_name.$tag.header														
}	

### function
function check_variable()	{
	message=$1
	if [[ "$2" == "" ]] 
	then 
		echo -e "\n************************************"
		echo "$message is not set correctly."
		echo -e "\n************************************"
		exit 1;
	fi		
}	

function check_file()	{
	if [[ ! -s $1 ]] 
	then 
		echo -e "\n************************************"
		echo "$1 doesn't exist or it is empty"
		echo -e "\n************************************"
		exit 1;
	fi		
}


function log_it ()	{
	command=$1
	file=$2
	eval $command
	echo -e "INFO $(date +%c) JobSubmission -\t$command\n" >> $file
}
	
# check for full path
function check_dir()	{
	message=$1
	if [ $2 == "." ]
	then
		echo -e "\n************************************"
		echo -e "$message : should be specified as complete path"
		echo -e "\n************************************"
		exit 1;
	fi	
}
			
# to check and validate the configuration file presence
function check_config()	{
	message=$1
	if [ ! -s $2 ]
	then
		echo -e "\n************************************"
		echo -e "$message : doesn't exist"
		echo -e "\n************************************"
		exit 1;
	fi	
	
	dir_info=`dirname $2`
	if [ $dir_info == "." ]
	then
		echo -e "\n************************************"
		echo -e "$message : should be specified as complete path ($dir_info)"
		echo -e "\n************************************"
		exit 1;
	fi
		
	du=`dos2unix $2 2>&1` 
	cat $2 | sed 's/^[ \t]*//;s/[ \t]*$//' > $2.tmp
	mv $2.tmp $2														
}	

function check_capturekit()	{
	chrs=$1
	capturekit=$2
	for i in `echo $chrs | tr ":" " "`
	do
		if [ `cat $capturekit | grep -w chr$i | wc -l` -le 0  ]
		then
			echo -e "\n************************************"
			echo -e "no chromosomal region in the capture bed file, \nplease remove the chromosome : chr$i from CHRINDEX tag from runinfo file"
			echo -e "\n************************************"
			exit 1;
		fi
	done	
}

function check_dir_exist()	{
	if [ ! -d $1 ]
	then
		echo -e "\n************************************"
		echo -e "$1 : folder doesn't exist"
		echo -e "\n************************************"
		exit 1;
	fi	
}	

function check_file_nonexist()	{
	if [ -f $1 ]
	then
		echo -e "\n************************************"
		echo -e "$1 : file already exist"
		echo -e "\n************************************"
		exit 1;
	fi	
}	

function check_cm_variable()	{
	if [ -z $1 ]
	then
		echo "Must provide at least required options. See output file for usage."
		exit 1;
	fi
}

function validate_catalog_file() {
  catalogs=$1
  outdir=$2

  if [ -z "$1" ]
  then 
    log_error "Must provide catalog file to validate_catalog_file"
    exit 100
  fi

  if [ -z "$2" ]
  then
    log_error "Must provide output directory for temp files."
    exit 100
  fi

  # Copy filtered version of drill and catalog files to $outdir and reassign variable.
  grep -v "^#" $catalogs > $outdir/catalog.tmp
  catalogs="$outdir/catalog.tmp"

  ##Validate catalog file
  #Make sure there are 3 columns
  VALIDATE_CATALOG=`awk '{if (NF != 3){print "Line number",NR,"is incorrectly formatted in ",FILENAME,"\\\n"}}' $catalogs`
  if [ ! -z "$VALIDATE_CATALOG" ]
  then
    log_error "${VALIDATE_CATALOG}"
    exit 100
  fi

  #Make sure the commands exist
  RES=`cut -f2 $catalogs |sort -u`
  for x in $RES
  do
    CHECK=${BIOR}/${x}
    if [ -z "$CHECK" ]
    then
      log_error "Can't find the ${BIOR}/$x command as specified in $catalogs"
      exit 100
    fi
  done

  echo "All commands found"
  #Make sure the catalogs exist
  RES=`cut -f3 $catalogs |sort -u`
  for x in $RES
  do
    if [ ! -e "$x" ]
    then
      log_error "Can't find the $x catalog as specified in $catalogs"
      exit 100
    fi
  done
  echo "$catalogs is validated" "dev"
}

# Assumptions:
#   Location of catalog file is: $outdir/catalog.tmp
function validate_drill_file() {
  drills=$1
  outdir=$2

  catalogs=$outdir/catalog.tmp

  grep -v "^#" $drills > $outdir/drills.tmp
  drills="$outdir/drills.tmp"

  ##Validate drill file
  #Make sure there are 3 columns
  VALIDATE_DRILL=`awk '{if (NF != 2 && NF != 3){print "Line number",NR,"is incorrectly formatted in ",FILENAME,"\\\n"}}' $drills`
  if [ ! -z "$VALIDATE_DRILL" ]
  then
    log_error "$VALIDATE_DRILL"
    exit 100
  fi

  #Make sure the drill values exist in the catalog and are formatted properly
  NUM_ROWS=`awk 'END{print NR }' $drills`
  while [ $NUM_ROWS -gt 0 ];
  do
    x=$NUM_ROWS
    KEY=$(awk -v var=$x '(NR==var){print $1}' $drills)
    TERMS=$(awk -v var=$x '(NR==var){print $2}' $drills)

    if [[ -z "$KEY" || -z "$TERMS" ]]
    then
      ${BIOR_ANNOTATE_DIR}/scripts/email.sh -f $drills -m bior_annotate.sh -M "Unable to retrieve drill name or terms" -p $drills -l $LINENO
      exit 100
    fi

    CATALOG=`grep -w ^$KEY $catalogs |cut -f3|head -1`
    COMMAND=`grep -w ^$KEY $catalogs |cut -f2|head -1`

    if [[ -z "$CATALOG" || -z "$COMMAND" ]]
    then
      ${BIOR_ANNOTATE_DIR}/scripts/email.sh -f $catalogs -m bior_annotate.sh -M "Unable to retrieve one of the catalog $CATALOG or command $COMMAND for key $KEY" -p $catalogs -l $LINENO
      exit 100
    fi

    IFS=',' all_terms=( $TERMS )
    for i in "${all_terms[@]}"
    do
      CHECK=""
      #Remove any trace of clipped terms
      IFS='|' editLabelEvents=( $editLabel )
      trim=$i
      #Remove the strings in the IDs that the user submits
      for k in "${editLabelEvents[@]}"
      do
        trim=${trim/$k/}  #log "TRIMMING trim=${trim/$k/}"
      done

      CHECK=`grep -w ${trim} ${CATALOG/tsv.bgz/}*columns.tsv`
      PASS=`grep -v "#" ${CATALOG/tsv.bgz/}*columns.tsv | perl -pne 's/\t\n//' |awk -F'\t' '(NF<4 && $1 !~/^#/)'`

      if [ ! -z "$PASS" ]
      then
        log_error "Missing description in ${CATALOG}. Suspect error in catalog.\nPASS=$PASS"
        exit 100
      fi

      if [ -z "$CHECK" ]
      then
        log_error "Can't find the ${trim} term in ${CATALOG}. Ensure you have specified the correct version in ${catalogs}."
        log "zcat $CATALOG|head -5000|grep -w ${trim}|head -1" "debug"
        exit 100
      fi
    done
    let NUM_ROWS-=1;
  done

  log "All drill values are validated" 

}	
