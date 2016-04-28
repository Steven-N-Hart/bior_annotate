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

function validate_drill_file() {
  echo "Not implemented"
}	
