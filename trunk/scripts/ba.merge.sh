#!/bin/sh
##################################################################################
###
###     Parse Argument variables
###
##################################################################################
usage(){
VAR=$(readlink -f $0)
echo "$VAR"
}
echo ""
echo "Running ba.merge"
echo "Options specified: $@"
VAR=$(readlink -f $0)
echo "$VAR"
KEEP_LINKS="FALSE"
uniqueOption="FALSE"

while getopts "uh:L:vo:t:T:d:r:ce:l:D:O:z:" OPTION; do
  case $OPTION in
    c) catalogs=$OPTARG ;;
    d) CREATE_DIR=$OPTARG ;;
    D) DIR=$OPTARG ;;
    e) editLabel=$OPTARG ;;
    h) echo "Read the instructions"
        exit ;;
    l) log=$OPTARG ;;
    L) KEEP_LINKS=$OPTARG ;;
    o) outname=$OPTARG ;;
	O) outdir=$OPTARG ;;
    r) drill=$OPTARG ;;
    t) table=$OPTARG ;;
    T) tool_info=$OPTARG ;;
	u) uniqueOption="TRUE" ;;
    v) echo "WARNING: option -v is deprecated." ;;
    z) COMPRESS=$OPTARG ;;
   \?) echo "Invalid option: -$OPTARG. See output file for usage." >&2
       usage
       exit ;;
    :) echo "Option -$OPTARG requires an argument. See output file for usage." >&2
       usage
       exit ;;
    *) echo "option $OPTION not recognized."
       exit ;;
  esac
done

source $tool_info
source "${BIOR_ANNOTATE_DIR}/scripts/shared_functions.sh"
source "${BIOR_ANNOTATE_DIR}/utils/log.sh"

if [ "$log" == "TRUE" ]
then
	set -x
fi

export PERL5LIB=$PERLLIB:$PERL5LIB

##################################################################################
###
###     Setup configurations
###
##################################################################################
#Count to make sure there are at least as many variants in the output as were in the input
for x in $CREATE_DIR/*anno
do
PRECWD_VCF=${x/.anno/}

if [ -z "$PRECWD_VCF"  ];
then
        log_error "Can't find PRECWD_VCF=$PRECWD_VCF ";
        exit 100;
fi
START_NUM=`cat $PRECWD_VCF|grep -v "^#"|wc -l|cut -f1 -d" "`
END_NUM=`cat $x|grep -v "^#"|wc -l|cut -f1 -d" "`
if [ ! "$END_NUM" -ge "$START_NUM" ];
then 
        log_error "$x has insufficient number of rows to be considered complete";
        log_error "PRECWD_VCF=$PRECWD_VCF START_NUM=$START_NUM END_NUM=$END_NUM";
        exit 100;
fi
if [ ${PRECWD_VCF: -3} == "000" ]
then
    #Add the header from the first file
	echo "##fileformat=VCFv4.1" > $CREATE_DIR/${outname}.vcf
    head -500 $x | grep "^##"|sort -u |$PERL -pne 's/$editLabel//g;s/\t\n/\n/' >> $CREATE_DIR/${outname}.vcf
    tail -n1 ${PRECWD_VCF%???}.header >> $CREATE_DIR/${outname}.vcf
fi
if [ "$uniqueOption" == "TRUE" ]
	then
		cat $x |$PERL ${BIOR_ANNOTATE_DIR}/scripts/MakeUniq.pl |uniq >> $CREATE_DIR/${outname}.vcf
	else
		cat $x|uniq >> $CREATE_DIR/${outname}.vcf
	fi
done

if [ "$table" != "0" ]
then
	if [ "$table" == 1 ]
	then
		$PERL $DIR/bior_vcf2xls.pl -i $CREATE_DIR/${outname}.vcf -o $CREATE_DIR/${outname}.tsv -c $CREATE_DIR/drill.table
	fi
	if [ "$table" == 2 ]
	then
		DRILLS=`cat $CREATE_DIR/drills.tmp|tr "\n" ","`
		$PERL $DIR/Info_extract2.pl $CREATE_DIR/${outname}.vcf -q $DRILLS|grep -v "^##" >  $CREATE_DIR/${outname}.tsv
	fi
fi	

if [[ "$KEEP_LINKS" == "FALSE" ]]
then
  perl -i -pe "s#;*Link_.*(|a>)##g" ${outname}.vcf
  perl -i -pe "s/^##INFO=<ID=$//" ${outname}.vcf
fi

if [[ "$COMPRESS" == "yes" ]]
then
  cat $CREATE_DIR/${outname}.vcf|$BEDTOOLS/sortBed -header|uniq |$TABIX/bgzip -c > $CREATE_DIR/${outname}.vcf.gz
  BEGINNING=`grep -v "^#" $CREATE_DIR/${outname}.vcf|$BEDTOOLS/sortBed -header|uniq|wc -l`
  FINAL=`zcat  $CREATE_DIR/${outname}.vcf.gz|grep -v "^#"|wc -l`
  if [ $FINAL -lt $BEGINNING ]
  then
    log_error "ERROR! Compression failed - only found $FINAL variants, expected $BEGINNING"
    exit 100
  fi
  $TABIX/tabix -f -p vcf $CREATE_DIR/${outname}.vcf.gz
  rm $CREATE_DIR/${outname}.vcf
else
  log_debug "Not compressing final file due to runtime option. Tabix index will also not be generated."
fi

mv $CREATE_DIR/${outname}* $outdir
cd $outdir
#Clean up
if [[ "$log" != "TRUE" && ! -z "$CREATE_DIR" ]]
then
  rm -r "$CREATE_DIR"
fi

