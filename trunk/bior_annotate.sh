#!/usr/bin/env bash
#set -o pipefail
##################################################################################
###
###     Name:           bior_annotate.sh
###     Creator:        Steven N Hart, PhD
###     Function:       This script is designed to create a central architecture for bior
###                                     annotations.  Using configuration files, the user specifies
###                                     which annotations from which catalogs they want to extract.
###                                     This script only works with bior_overlap and bior_same_varaint.
###                                     It will split the number of annotation jobs into X variants per
###                                     file, which then get sent to the cluster for annotation.  It
###                                     Automatically seperates multi-VCF records to 1 per row.
###                                     There are a couple of PATHS that need to be checked below.
###
##################################################################################
##fix
usage ()
{
cat << EOF
##########################################################################################################
##
## Script Options:
##   Required:
##      -o    Output file prefix [required] 
##              Note: ***Name only, not PATH***
##              Result files will take the form: <output_prefix>.vcf.gz, etc.
##      -O    May be used to specify an output directory [recommended, default:cwd]
##      -v    path to the VCF to annotate     [required]
##   Optional:
##      -c    path to catalog file
##      -d    Path to the drill file
##      -e    This option substitutes an expression to blank (e.g. some unecessary info form bior) [bior\.\.|INFO\.|Info\.|bior\.]
##      -h    Display this usage/help text
##      -j    job name for qsub command
##      -l    set logging
##      -L    Add link references to VCF [default: filter out link references]
##      -M    memory info file from GGPS
##      -n    Number of lines to split the data into  [default:20000]
##      -s    Flag to turn on SNPEFF
##      -a    Flag to turn off CAVA annotation
##      -Q    queue override (e.g. 1-day) [defaults to what is in the tool_info]
##              * Use -Q NA for standalone mode
##      -t    Export table as well as VCF [1]
##              -t 1: Separate columns for Depth, GQ, AD, and GT per sample
##              -t 2: First N columns like VCF, one colulmn containing sample names
##      -T    tool info file
##      -x    path to temp directory [default: cwd]
##      -z    specify yes or no to describe whether the final VCF should be compressed [default: yes]
##	-u    only report 1 row for each chr, pos, ref, alt (use with extreme caution)
##
##
##	Clinical specific options (DLMP use only)
##      -P    PEDIGREE file (for trios only, this will add extra annotations)
##      -g    GENE list (only used with pedigrees)
##
#########################################################################################################

Examples:
        cat catalog_file
                Clinvar bior_same_variant       /data5/bsi/epibreast/m087494.couch/Reference_Data/ClinVar/Clinvar.tsv.bgz
                HPO     bior_overlap    /data5/bsi/catalogs/user/v1/gene_ontology/HPO/2014_10_21/HPO_Gene_w_coordinates.catalog.gz
                ExAC    bior_same_variant       /data5/bsi/catalogs/user/v1/ExAc/2014_10_22/ExAC.r0.1.catalog.gz
                ...
                Note:   column 1 is the ShortUniqueName in the *datasource.properties file for that catalog
                        column 2 is what bior command you wish to run [e.g. overlap or same variant]
                        column 3 is the path to the catalog

                        The name in the catalog_file must match the name in the drill_file EXACTLY

        cat drill_file
                Clinvar RCVaccession,ReviewStatus,ClinicalSignificance,OtherIDs,Guidelines
                HPO     HPO-term-name
                ExAC    Info.AC,Info.AN,Info.AF,Info.AC_Het,AC_Hom
                ...

                Note:  column 1 is the ShortUniqueName in the *datasource.properties file for that catalog
                       column 2 is what features you want to drill out of that catalog

                       The name in the drill_file must match the name in the catalog_file EXACTLY

####

EOF
}

### Defaults ###
runCAVA="-c"
table=0
outdir=$PWD
START_DIR=$PWD
TEMPDIR=$PWD
NUM=20000
log="FALSE"
COMPRESS="yes"
KEEP_LINKS="TRUE"
uniqOption=""

##################################################################################
###
###     Parse Argument variables
###
##################################################################################


while getopts "ac:Cd:e:g:hj:k:lLM:n:o:O:P:sQ:t:T:uv:x:z:" OPTION; do
  case $OPTION in
    a)  runCAVA="" ;;
    c)  catalogs=$OPTARG ;;     #
    C)  CLINICAL="TRUE" ;;
    d)  drills=$OPTARG ;;       #
    e)  editLabel=$OPTARG ;;
    g)  GENE_LIST=$OPTARG ;;    #
    h)  usage                   #
        exit ;;
    j)  job_name=$OPTARG ;;     #
    k)  job_suffix=$OPTARG ;;
    l)  log="TRUE" ;;           #
    L)  keepLinks="TRUE" ;;      #
    M)  memory_info=$OPTARG ;; #
    n)  NUM=$OPTARG ;;       #
    o)  outname=$OPTARG ;;   #
    O)  outdir=$OPTARG ;;    #
    P)  PEDIGREE=$OPTARG ;;     #
    s)  runsnpEff="-s" ;;         #
    Q)  QUEUEOVERRIDE=$OPTARG ;; #
    t)  table=$OPTARG ;;           #
    T)  tool_info=$OPTARG ;;     #
    u)  uniqOption="-u" ;;
    v)  VCF=$OPTARG ;;           #
    x)  TEMPDIR=$OPTARG ;;       #
    z)  if [[ "$OPTARG" == "yes" || "$OPTARG" == "no" ]];  then
          COMPRESS=$OPTARG
        else
          usage
          echo "-z must use either \"yes\" or \"no\""
          exit
        fi
        ;;
    \?) echo "Invalid option: -$OPTARG. See output file for usage." >&2
        usage
        exit ;;
    :)  echo "Option -$OPTARG requires an argument. See output file for usage." >&2
        usage
        exit ;;
  esac
done

if [ "$log" == "TRUE"  ]; then
	set -x
fi



##################################################################################
###
###     Setup configurations
###
##################################################################################

if [ -z "$tool_info" ]; then
	#If the user doesn't specify a Tool info, try to find the default location
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	tool_info=${DIR}/config/tool_info.txt
	# But, we may not be in the same directory as bior_annotate.sh, so if it is on the path, then use that
	if [ ! -f "$tool_info" ]; 	then
		tool_info=$(dirname `which bior_annotate.sh`)/config/tool_info.txt
	fi
fi
source $tool_info
# Add BIOR to PATH
# Example of BIOR from tool_info.txt:  /usr/local/biotools/bior_scripts/4.3.0/bior_pipeline-4.3.0/bin
# NOTE: This is the bin dir of BioR
# Do not need the BIOR_PROFILE variable then
export PATH=$BIOR:$PATH
export BIOR_LITE_HOME=`dirname $BIOR`



#Make sure the BIOR_ANNOTATE_DIR is set in tool info since many scripts downstream will need its location
if [ -z "$BIOR_ANNOTATE_DIR" ]; then
	echo "The BIOR_ANNOTATE_DIR is not set in your tool_info file ($tool_info)"
	exit 100
fi

if [ ! -f ${BIOR_ANNOTATE_DIR}/utils/log.sh ]; then
 echo "ERROR: Cannot find ${BIOR_ANNOTATE_DIR}/utils/log.sh"
 exit 100;
else
 source ${BIOR_ANNOTATE_DIR}/utils/log.sh
fi



if [ -z "$catalogs" ]; then
	catalogs=${BIOR_ANNOTATE_DIR}/config/catalog_file
fi

if [ -z "$drills" ]; then
	drills=${BIOR_ANNOTATE_DIR}/config/drill_file
fi

if [ -z "$memory_info" ]; then
	memory_info=${BIOR_ANNOTATE_DIR}/config/memory_info.txt
fi

if [ ! -f ${BIOR_ANNOTATE_DIR}/utils/file_validation.sh ]; then
 echo "ERROR: Cannot find ${BIOR_ANNOTATE_DIR}/utils/file_validation.sh"
 exit 100;
else
 source ${BIOR_ANNOTATE_DIR}/utils/file_validation.sh
fi

#Make sure I have the full path of the files I need
#Check for required arguments
if [ ! -s "$catalogs" -o ! -s "$drills" -o ! -s "$VCF" -o -z "$outname"  ]; then
  usage
  echo "ERROR: A required input parameter does not exist or the file is empty. Please check for typos."
  echo "CATALOGS=$catalogs"
  ls -lh $catalogs
  echo "DRILLS=$drills"
  ls -lh $drills
  echo "VCF=$VCF"
  ls -lh $VCF
  echo "outname=$outname"
  exit 100
fi

if  [[ $outname == *"/"* ]]; then
  usage 
  echo "Please do not use a path for the output file name."
  exit 100
fi


if [ -z "$tool_info" ]; then
    if [ "$QUEUEOVERRIDE" == "NA" ]; then
      echo "No tool_info specified, using $tool_info"
    else
      echo "A tool_info file is required when submitting to the grid."
      exit 100
    fi
fi

if [ -z "$memory_info" ]; then
    if [ "$QUEUEOVERRIDE" == "NA" ]; then
      echo "No memory_info specified, using $memory_info"		
    else
      echo "A memory_info file is required when submitting to the grid."
      exit 100
    fi
fi

# Make sure this is a path to a real file, not just a symlink.
tool_info=`readlink -m ${tool_info}`
memory_info=`readlink -m ${memory_info}`

#Makes sure files exist
if [ ! -s "$tool_info" -o ! -s "$memory_info" ]; then
	echo "Check the location of your tool and memory info files"
	echo "tool_info=$tool_info"
	echo "memory_info=$memory_info"
	exit 100
fi

# Display the configuration files so the user knows where to find each one
cat << EOF

Using the following configuration files for this run:
  Catalog list: $catalogs
  Drill list:   $drills
  Tool info:    $tool_info
  Memory info:  $memory_info

EOF

source ${tool_info}
source ${memory_info}

# This variable should be defined in the tool_info file.
if [ -z "${BIOR_ANNOTATE_DIR}" ]; then
  echo "BIOR_ANNOTATE_DIR is not defined in $tool_info. This is a required variable."
  exit 100
fi

source ${BIOR_ANNOTATE_DIR}/utils/log.sh
source ${BIOR_ANNOTATE_DIR}/utils/file_validation.sh
source ${BIOR_ANNOTATE_DIR}/scripts/shared_functions.sh


##Override QUEUE if set
if [ ! -z "${QUEUEOVERRIDE}" ]; then
  QUEUE=${QUEUEOVERRIDE}
fi

catalogs=`readlink -m ${catalogs}`
drills=`readlink -m ${drills}`
VCF=`readlink -m ${VCF}`

# PERLLIB should be set in the tool_info
export PYTHONPATH=${PERLLIB}
#Needed for splitting multi-VCF
export PERL5LIB=${PERL5LIB}
export SCRIPT_DIR=${BIOR_ANNOTATE_DIR}/scripts

if [ ! -d "$SCRIPT_DIR" ]; then
  log_error "Variable not set correctly SCRIPT_DIR=$SCRIPT_DIR"
  exit 100
fi

#As of version 3.0, we only support CAVA VERSION 1.2+
CAVA_VERSION=$($PYTHON/python $CAVA --version)
#Make sure the version is greater than v1.1
CAVA_VALID=$(echo $CAVA_VERSION|perl -ne 's/v//;@ver=split(/\./,$_);if(($ver[0]<=1)&&($ver[1]<=1)){print "NOT OKAY"}')
if [ -z "$CAVA_VERSION" -o ! -z "$CAVA_VALID" ]; then
	echo "Please check that your CAVA version is at least 1.2+"
	echo "We no longer support CAVA <=v1.1"
	exit 100
fi
#Check the database to make sure it is in the proper format, since 1.1 databases won't work
CAVA_DB=$(grep ensembl $CAVA_CONFIG |awk '{print $3}' )
if [ -z "$CAVA_DB" ]; then
	echo "You either do not have a database set in your cava config ($CAVA_CONFIG) or"
	echo "You do not have a space here: @ensembl = /path/to/ensembl"
	exit 100
fi
#In cava 1.2+, the 4th column contains transcript info, which should contain the term "kb"
COLUMN_4=$(zcat $CAVA_DB|head -1|cut -f4)
if [[ $COLUMN_4 != *"kb"* ]]; then 
	echo "Please ensure that your cava database is compatible with cava version v1.2+."
	echo "To verify, the 4th column in your ensembl file should contain \"kb\""
	exit 100
fi


INFO_PARSE=${SCRIPT_DIR}/Info_extract2.pl
VCF_SPLIT=${SCRIPT_DIR}/VCF_split.pl
#  check_variable "$TOOL_INFO:BIOR_PROFILE" $BIOR_PROFILE
#  source $BIOR_PROFILE
check_variable "$TOOL_INFO:PERL" $PERL
check_variable "$TOOL_INFO:VT" $VT
check_variable "$TOOL_INFO:BEDTOOLS" $BEDTOOLS

if [ ! -z "$PEDIGREE" -a "$PEDIGREE" != "NA" ]; then
	PEDIGREE=`readlink -m $PEDIGREE`
	PEDIGREE=" -p $PEDIGREE "
fi

if [ ! -z "$GENE_LIST" ] ; then
	GENE_LIST=`readlink -m $GENE_LIST`
	GENE_LIST="-g $GENE_LIST"
fi

EMAIL=`finger $USER|grep Name|cut -f4|$PERL -pne 's/(.*;)(.*)(;.*)/$2/'`
if [ -z "${EMAIL}" ]; then
  log_warning "${USER} not found via finger. You will not receive email notifications."
fi



##################################################################################
###
###     Start to build the scripts
###
##################################################################################

if [ "$log" == "TRUE" ]; then
	set -x
fi


#Start off by creating a random directory to make sure we never have naming conflicts
CREATE_DIR=$RANDOM
# if we accidentally create a directory that already exists, try again.
until [ ! -e "$TEMPDIR/.bior.${CREATE_DIR}" ]
do
  CREATE_DIR=$RANDOM
done

#Do all work in working directory
mkdir $TEMPDIR/.bior.${CREATE_DIR}
cd $TEMPDIR/.bior.${CREATE_DIR}
TEMPDIR=$PWD

##################################################################################
###
###     QC check all the inputs
###
##################################################################################

validate_catalog_file $catalogs $TEMPDIR
validate_drill_file $drills $TEMPDIR

#Calculate the number of catalogs
NUM_CATALOGS_TO_DRILL=`awk 'END{print NR }' $drills`

##################################################################################
###
###     Split the VCF file into manageable chunks
###
##################################################################################

# Get the output filename without the .gz extension (if it was used)
VCF_NO_SAMPLES=`basename $VCF | sed 's/\.gz$//g'`
LINE_NUMS_AND_SAMPLES_FILE=lineNumsAndSamples.tsv.gz

# GROOVY_HOME should be set from the tool_info.txt file
# Ex: export GROOVY_HOME=/data5/bsi/bictools/src/groovy/2.4.7/
if [ -z "$GROOVY_HOME" ] || [ ! -d "$GROOVY_HOME" ]; then
  echo "ERROR: Could not find GROOVY_HOME path or GROOVY_HOME was not an existing directory: $GROOVY_HOME"
  exit 1
fi
export PATH=$GROOVY_HOME/bin:$PATH

#----------------------------------------------------------
# Remove the sample and format columns  (NOTE: THIS *MUST* BE DONE BEFORE THE SPLIT OR THE LINES WON'T MATCH THE ORIGINAL VCF!)
# Split the VCF by ALTS (taking into account other fields related to ALTS)
# Remove the lines containing "NON_REF" (???)
# Remove space or tabs at end of lines
# If line is NOT header, split it by tab (and????)
# Run VT-Normalize to trim alt and ref strings as necessary
# Remove IDs from VCFs b/c bior uses them incorrectly
# NOTE:  VCF_split.pl adds columns: FORMAT, SAMPLE as 9th and 10th cols
#----------------------------------------------------------
zcat -f $VCF|\
  $PERL $VCF_SPLIT|\
  grep -v 'NON_REF'  |\
  $PERL -pne 's/[ |\t]$//g'  |\
  $PERL -ne 'if($_!~/^#/){$_=~s/ //g;@line=split("\t",$_);$rsID=".";print join("\t",@line[0..1],$rsID,@line[3..@line-1])}else{print}'  |\
  $VT/vt normalize $VT_OPTIONS -r $REF_GENOME -   |\
  groovy ${SCRIPT_DIR}/cutSamples.groovy  $LINE_NUMS_AND_SAMPLES_FILE \
  >  $VCF_NO_SAMPLES


if [ "$CLINICAL" == "TRUE" ]; then
	#Split PEDIGREE and VCF_NO_SAMPLES to only contain the 3 target samples
	PEDIGREE=${PEDIGREE##*p }
	PEDIGREE=${PEDIGREE/ /}
	log "$PYTHON/python $SCRIPT_DIR/PEDsplit_AddGT.py $TEMPDIR/$VCF_NO_SAMPLES $PEDIGREE $PEDIGREE.3 $TEMPDIR/${VCF_NO_SAMPLES/.vcf/.trio.vcf} $tool_info"
	$PYTHON/python $SCRIPT_DIR/PEDsplit_AddGT.py $TEMPDIR/$VCF_NO_SAMPLES $PEDIGREE $PEDIGREE.3 $TEMPDIR/${VCF_NO_SAMPLES/.vcf/.trio.vcf} $tool_info
	PEDIGREE="-p $PEDIGREE.3"
	VCF_NO_SAMPLES=${VCF_NO_SAMPLES/.vcf/.trio.vcf}
fi

###=============================================================================================================
#---------------------------------------------------------------
# SPLIT the VCF files into maneageable chunks
#---------------------------------------------------------------
function splitVcfIntoSmallChunks {
  # Dump the header to a file
  cat $VCF_NO_SAMPLES|$PERL -pne 's/[ |\t]$//g'|head -1000|grep "^#" | grep -v "##SAMPLE" >  ${VCF_NO_SAMPLES}.header
  # If the file is blank, throw an error
  if [ ! -s "${VCF_NO_SAMPLES}.header" ]; then
    log_error "Failed to generate header for VCF, check $VCF_NO_SAMPLES to ensure the file exists and is formatted correctly."
    exit 100
  fi

  # Split into chunks of size $NUM (-l),  with numeric suffixes (-d) of length 3 (-a), 
  # reading from STDIN (-), using prefix ${VCF_NO_SAMPLES}
  cat $VCF_NO_SAMPLES|$PERL -pne 's/[ |\t]$//g'|grep -v "^#"|split -d -l $NUM -a 3 - ${VCF_NO_SAMPLES}

  # Verify the file was split into multiples
  FIND_RESULTS=`find $TEMPDIR -maxdepth 1 -name "${VCF_NO_SAMPLES}[0-9]*" -print -quit`
  if [ -z "$FIND_RESULTS" ]; then
    log_error "VCF split appears to have failed. Please check $TEMPDIR to ensure that the VCF file ${VCF_NO_SAMPLES} is valid."
    exit 100
  fi

  #Add a header to each file
  for chunk in ${VCF_NO_SAMPLES}[0-9]*;  do
    cat ${VCF_NO_SAMPLES}.header $chunk > ${VCF_NO_SAMPLES}.tmp
    mv ${VCF_NO_SAMPLES}.tmp $chunk
  done
}

###=============================================================================================================
function mergeAnnotatedFilesWithOriginalSampleColumns {
 	ANNOTATED_FILES_DIR=$(dirname $VCF_NO_SAMPLES)
	OUTPUT_VCF_BGZ=${outdir}/${outname}.vcf.gz

	# If user decided to run interactively (NOT use the grid engine)
	if [ "$QUEUE" == "NA" ]; then
    	COMMAND="${SCRIPT_DIR}/merge.sh  $tool_info  $LINE_NUMS_AND_SAMPLES_FILE  $ANNOTATED_FILES_DIR  $OUTPUT_VCF_BGZ"
		log $COMMAND
		eval $COMMAND
	else
		JOB_NAME=""
		if [ "$job_name" ]; then JOB_NAME="${job_name}."; fi
		JOB_SUFFIX=""
		if [ "$job_name" ] && [ "$job_suffix" ]; then JOB_SUFFIX=".${job_suffix}"; fi
		log "annotate_ba_merge (memory setting): $annotate_ba_merge"
		COMMAND=$"$args $hold -l h_vmem=$annotate_ba_merge -N ${JOB_NAME}baMerge${JOB_SUFFIX}  ${SCRIPT_DIR}/merge.sh   $tool_info  $LINE_NUMS_AND_SAMPLES_FILE  $ANNOTATED_FILES_DIR  $OUTPUT_VCF_BGZ"
		log "Merging the annotated files with the original FORMAT and SAMPLE columns"
		log "$COMMAND"
		log "VCF In:               $VCF"
		log "ANNOTATED_FILES_DIR:  $ANNOTATED_FILES_DIR"
		log "OUTPUT_VCF_BGZ:       $OUTPUT_VCF_BGZ"
		eval "$COMMAND"

		# NOTE: Do we need to handle the "UNIQUE" flag that used to be on merge?
	fi
}


# Split the file -----------------
splitVcfIntoSmallChunks


##################################################################################
###
###     Fire off the qsubs for each split VCF file
###
#################################################################################
#---------------------------------------------------------------------------------------------
# No Grid Engine Used
#---------------------------------------------------------------------------------------------
args="$SGE_BASE/qsub -cwd -q $QUEUE -m a -notify -M $EMAIL -l h_stack=$SGE_STACK"
# The QUEUE option determines whether to run on the SunGridEngine ("1-hour","1-day", etc) or interactively ("NA")
if [ "$QUEUE" == "NA" ] ; then
	for x in ${VCF_NO_SAMPLES}[0-9][0-9][0-9] ; do
		log "sh $SCRIPT_DIR/annotate.sh -c $catalogs -d $drills -T $tool_info -v $x"
		sh $SCRIPT_DIR/annotate.sh -c $catalogs -d $drills -T $tool_info -v $x
        log ""
        # Run SnpEffect, CAVA, PEDIGREE
		log_dev "$SCRIPT_DIR/ba.program.sh -v ${x}.anno -d ${drills} -M ${memory_info} -D ${SCRIPT_DIR} -T ${tool_info} -t ${table} -l ${log} ${PROGRAMS} -j ${INFO_PARSE} ${runsnpEff} ${runCAVA} ${PEDIGREE} ${GENE_LIST} ${bior_annotate_params}" 
		sh $SCRIPT_DIR/ba.program.sh -v ${x}.anno -d ${drills} -M ${memory_info} -D ${SCRIPT_DIR} -T ${tool_info} -t ${table} -l ${log} ${PROGRAMS} -j ${INFO_PARSE} ${runsnpEff} ${runCAVA} ${PEDIGREE} ${GENE_LIST} ${bior_annotate_params}
	done
	log ""
  
	# MIKE---------------
	# Exit here to keep the output files in place
	# exit 1
  
	mergeAnnotatedFilesWithOriginalSampleColumns

	cd $START_DIR
	###---------------------------------------
	###  NOTE: We're exiting here!
	###---------------------------------------
	exit 0
fi
#---------------------------------------------------------------------------------------------


#---------------------------------------------------------------------------------------------
# Grid Engine Used  (from here to end of script)
#---------------------------------------------------------------------------------------------
# Ensure that user is not attempting to use local locations like /tmp, /local1/tmp, or /local2/tmp. 
# These will fail when submitting to the grid.
for WORKING_DIR in "$outdir" "$TEMPDIR"; do
  for LOCAL_DIR in "/tmp" "/local1/tmp" "/local2/tmp";  do
    if [[ "$WORKING_DIR" == "$LOCAL_DIR"* ]]; then
      log_error "$LOCAL_DIR is a local filesystem that is not available on the grid nodes. Please modify your job settings and try again."
      exit 100
    else
      log_debug "WORKING_DIR=$WORKING_DIR, LOCAL_DIR=$LOCAL_DIR" 
    fi
  done
done

# If you are at this point, then you will be submitting jobs to the sun grid engine
#command -v $SGE_BASE/qsub >/dev/null 2>&1 || { log >&2 "I require qsub but it's not installed.  Aborting.";exit 1}

for x in ${VCF_NO_SAMPLES}[0-9][0-9][0-9]; do
    NAME=annotatevcf
	if [ "$job_name" ]; then
		if [ "$job_suffix" ]; then
			NAME="$job_name.annotatevcf.$job_suffix"
		else
			NAME="$job_name.annotatevcf"
		fi
	fi	
	command=$"$args -l h_vmem=$annotate_mem -N $NAME $SCRIPT_DIR/annotate.sh -c $catalogs -d $drills -T $tool_info -v $x"
	JOB1=`eval "$command" |cut -f3 -d ' ' `
	 
	if [ "$log" == "TRUE" ]; then
        log "$args -hold_jid $JOB1 -l h_vmem=$annotate_ba_mem -N baProgram $SCRIPT_DIR/ba.program.sh $bior_annotate_params|cut -f3 -d ' ' >>jobs"
	fi
	
	if [ "$job_name" ]; then
		if [ "$job_suffix" ]; then
			command=$"$args -hold_jid $JOB1 -l h_vmem=$annotate_ba_mem -N $job_name.baProgram.$job_suffix $SCRIPT_DIR/ba.program.sh -v ${x}.anno -d ${drills} -M ${memory_info} -D ${SCRIPT_DIR} -T ${tool_info} -t ${table} -l ${log} ${PROGRAMS} -j ${INFO_PARSE} ${runsnpEff} ${runCAVA} ${PEDIGREE} ${GENE_LIST} $bior_annotate_params"
			hold="-hold_jid $job_name.baProgram.$job_suffix"
		else
			command=$"$args -hold_jid $JOB1 -l h_vmem=$annotate_ba_mem -N $job_name.baProgram $SCRIPT_DIR/ba.program.sh -v ${x}.anno -d ${drills} -M ${memory_info} -D ${SCRIPT_DIR} -T ${tool_info} -t ${table} -l ${log} ${PROGRAMS} -j ${INFO_PARSE} ${runsnpEff} ${runCAVA} ${PEDIGREE} ${GENE_LIST} $bior_annotate_params"
			hold="-hold_jid $job_name.baProgram"
		fi
	else
		command=$"$args -hold_jid $JOB1 -l h_vmem=$annotate_ba_mem -N baProgram $SCRIPT_DIR/ba.program.sh -v ${x}.anno -d ${drills} -M ${memory_info} -D ${SCRIPT_DIR} -T ${tool_info} -t ${table} -l ${log} ${PROGRAMS} -j ${INFO_PARSE} ${runsnpEff} ${runCAVA} ${PEDIGREE} ${GENE_LIST} $bior_annotate_params"
		hold="-hold_jid baProgram"
	fi
	eval "$command"
done
#the only reason I'm putting this into a variable is so it doesn't output the qsub notification to the screen
#hold="-hold_jid baProgram"
if [ "$log" == "TRUE" ]; then
	log "$args -hold_jid baProgram -l h_vmem=$annotate_ba_merge -pe threaded 2 -N baMerge $SCRIPT_DIR/ba.merge.sh -t ${table} -d ${CURRENT_LOCATION} -o ${outname} -T $tool_info -r $drills -s $runsnpEff  -D $SCRIPT_DIR ${uniqOption}"
	LOG="-l"
fi




# ----- MIKE -->
# Exit so we can see what the annotated files look like
#exit 1
# <<<-- MIKE ---

mergeAnnotatedFilesWithOriginalSampleColumns


log "You will be notified by e-mail as your jobs are processed. The baMerge job will be the last to complete."
log "** NOTE: when submitting to SGE, there will be multiple jobs created. You can monitor your jobs using qstat. **"

# Return to where you started
if [ ! -z "$TEMPDIR" ]; then
	cd $START_DIR
fi


echo "DONE. (bior_annotate.sh)----------------------------------------------------"
