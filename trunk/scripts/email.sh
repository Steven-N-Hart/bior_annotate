#! /usr/bin/env bash
#set -x
####################
## Script Options ##
####################
usage ()
{
cat << EOF
######################################################################
##	script to send an email to the user if something fails and set the script to exit 100;
##	qsub path is hard coded in this script
##
## Script Options:
##	-f	<file>	-	(REQUIRED) file name missing or corrupted
##	-m	<main_script>	-	(REQUIRED) name of the script where there is a failure
##	-p	<paramters>	-	(REQUIRED) paramters to the script taht failed
##	-l	<lineno>	-	(REQUIRED) lineno of the parent script
##	-s	<sub_script>	-	sub script which is failed
##	-h	- Display this usage/help text (No arg)
#############################################################################
EOF
}
echo "Options specified: $@"

while getopts "f:m:p:l:M:s:h" OPTION; do
  case $OPTION in
	M) message=$OPTARG ;;
	s) sub_script=$OPTARG ;;
	h) usage
	exit ;;
	f) file=$OPTARG ;;
    m) main_script=$OPTARG ;;
	p) parameters="${OPTARG}" ;;
	l) line=$OPTARG ;;
   \?) echo "Invalid option: -$OPTARG. See output file for usage." >&2
       usage
       exit ;;
    :) echo "Option -$OPTARG requires an argument. See output file for usage." >&2
       usage
       exit ;;
  esac
done


if [ -z "$file" ] || [ -z "$main_script" ] || [ -z "$parameters" ] ;
then
	echo "Must provide at least required options. See output file for usage." >&2
	usage
	exit 1;
fi

dir=`dirname $file`
if [ -d $dir ]
then
	export TMPDIR=$dir
fi	
if [ "$SGE_TASK_ID" ];then SGE_TASK=$SGE_TASK_ID;else SGE_TASK="-";fi	

##get the email
email=`finger $USER | awk -F ';' '{print $2}' | head -n1`
if [ "$sub_script" ]
then
	check="$sub_script in $main_script"
else
	check="$main_script"
fi	
SUB="Error in GENOMEGPS work flow executing $main_script"
date=`date`
if [ "$message" ]
then
	extra_message="Error message from the script:\n$message"
fi	
MESG="Date: $date\n============================\n\nMissing/Corrupted Filename:\n$file\n\n";

if [ "$JOB_NAME" ]
then
	MESG_JOB="JobName: $JOB_NAME\nJobId: $JOB_ID\nArrayJobId: $SGE_TASK\n\n
	Please check SGElog files:
	$SGE_STDERR_PATH\n
	$SGE_STDOUT_PATH\n"
	#### jobs to check
	SGE_PATH="/home/oge/ge2011.11/bin/linux-x64"
	jobs2check=`$SGE_PATH/qstat -j $JOB_NAME | grep jid_predecessor_list | awk '{print $3}' | tr ","  "\n"`
	MESG_jobs2check="\nUser may wants to check predecessor script to look for error \n$jobs2check \n";
else
	MESG_JOB=""
	jobs2check=""
fi 



MESG_PARAM="\nAn error has occurred at line# : $line\n\nParameters used for the script: $check are \n
$parameters\n
$extra_message\n
\nPlease fix the error, and issue 'qmod -c $job_id'  if you are running on cluster so that job can resume properly\n\nThank you\nWorkflow team"
## send the completion email
FINAL_MESG=$MESG$MESG_JOB$MESG_jobs2check$MESG_PARAM
echo -e "$FINAL_MESG" | /bin/mailx -s "$SUB" "$email"
sleep 15s

	
