#!/bin/bash
##################################################################################
###
###     Parse Argument variables
###
##################################################################################
echo ""
echo "Running ba.program"
echo "Options specified: $@"| tr "-" "\n"
while getopts "D:g:p:M:v:sT:d:t:l:j:hLcC:" OPTION; do
  case $OPTION in
    h) echo "Read the instructions"
        exit ;;
    v) CWD_VCF=$OPTARG ;;
    s) runsnpeff="TRUE" ;;
    T) tool_info=$OPTARG ;;
	c) runCAVA="TRUE" ;;
    d) drills=$OPTARG ;;
    t) table=$OPTARG ;;
    l) log=$OPTARG ;;
    j) INFO_PARSE=$OPTARG ;;
    p) PEDIGREE=$OPTARG ;;
    g) GENE_LIST=$OPTARG ;;
    L) LINKOFF="TRUE" ;;
    M) MEM_INFO=$OPTARG ;;
	C) CREATE_DIR=$OPTARG ;;
	D) DIR=$OPTARG ;;
   \?) echo "Invalid option: -$OPTARG. See output file for usage." >&2
       usage
       exit ;;
    :) echo "Option -$OPTARG requires an argument. See output file for usage." >&2
       usage
       exit ;;
  esac
done
if [ -z "$tool_info" ]
then
	echo "ERROR: The tool info file is a required parameter."
	exit 100
fi
source "$tool_info"
source "$MEM_INFO"
source "$BIOR_PROFILE"
source "${BIOR_ANNOTATE_DIR}/scripts/shared_functions.sh"
source "${BIOR_ANNOTATE_DIR}/utils/log.sh"

if [[ -z "$CWD_VCF" || ! -e "$CWD_VCF" || ! -s "$CWD_VCF" ]]
then
   ${DIR}/email.sh -f \$CWD_VCF -m ba.program.sh -M "VCF file does not exist" -p \$VCF -l \$LINENO
   exit 100
fi

export PYTHONPATH=$PYTHON:$PYTHONLIB
export PERL5LIB=$PERLLIB:$PERL5LIB
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH
SNPEFF_PARSE=${BIOR_ANNOTATE_DIR}/scripts/SNPeff_parse.pl
SAVANT_PARSE=${BIOR_ANNOTATE_DIR}/scripts/savant.label.pl
CAVA_PARSE=${BIOR_ANNOTATE_DIR}/scripts/cava.parse.pl 
INHERITANCE=${BIOR_ANNOTATE_DIR}/scripts/Inheritance.pl
COMPOUNDHET=${BIOR_ANNOTATE_DIR}/scripts/CompoundHet.pl
LINKS=${BIOR_ANNOTATE_DIR}/scripts/AddLinksToVCF.pl
TRIM=${BIOR_ANNOTATE_DIR}/scripts/VCF_remove.pl
export JAVA_HOME=$JAVA7


DRILLS=`$PERL -ane '$string="";@array=split(",",$F[1]);for ($i=0;$i<@array;$i++){$string=$string.";$F[0].$array[$i]"}{$string=~s/^,//;print $string}' $drills`
if [ "$log" == "TRUE" ]
then
	set -x
fi
START_NUM=`egrep -v "^#|^$" $CWD_VCF |wc -l|cut -f1 -d" "`

if [ "$runsnpeff" == "TRUE" ]
then
  if [ -z "$snpeff_mem" ]
  then 
    log_error "SNP-Effect: memory_info does not specify <snpeff_mem> variable" 
  fi

  log_dev "Running SNPeff"
  $JAVA7/java -Xmx$snpeff_mem -jar $SNPEFF/snpEff.jar $SNPEFF_params -c $SNPEFF/snpEff.config $SNPEFF_DB $CWD_VCF > $CWD_VCF.tmp
  $PERL $SNPEFF_PARSE  $CWD_VCF.tmp > $CWD_VCF
  END_NUM=`grep -v "^#" ${CWD_VCF}|wc -l|cut -f1 -d" "`
  if [ ! "$END_NUM" -ge "$START_NUM" ];
  then 
    log_error "Detected failure in ${CWD_VCF}: Started with $START_NUM lines, ended with $END_NUM" 
    exit 100
  fi
fi

if [ "$runCAVA" == "TRUE" ]
then
  log_dev "Running CAVA"
  $PYTHON/python $CAVA -c $CAVA_CONFIG -i $CWD_VCF -o $CWD_VCF.tmp
  if [ ! -f $CWD_VCF.tmp.vcf ]; then
    log_error "CAVA FAILED TO RUN with the following command"
    log_error "$PYTHON/python $CAVA -c $CAVA_CONFIG -i $CWD_VCF -o $CWD_VCF.tmp"
    exit 100
  fi

  cat $CWD_VCF.tmp.vcf |$PERL $CAVA_PARSE - |$PERL -pne 's/\s\n/\n/' > $CWD_VCF.tmp2.vcf
  mv $CWD_VCF.tmp2.vcf $CWD_VCF.tmp.vcf
  END_NUM=`egrep -v "^#|^$" ${CWD_VCF}.tmp.vcf |wc -l|cut -f1 -d" "`
  if [ ! "$END_NUM" -ge "$START_NUM" ];
  then 
    log_error  "${CWD_VCF}. CAVA has insufficient number of rows (expected at least $START_NUM, but found only $END_NUM). CAVA Failed"
    exit 100
  fi
  mv $CWD_VCF.tmp.vcf $CWD_VCF
fi

#IF PEDIGREE is specified, and AF, then you can run
if [ ! -z "$PEDIGREE" ]
then
  log_debug "PEDIGREE = $PEDIGREE"
  if [ ! -z "GENE_LIST" ]
  then
    GENE_LIST=" -g $GENE_LIST "
  fi

  if [[ $DRILLS == *ExAC* ]]; 
  then 
    echo "$PERL $INHERITANCE -v $CWD_VCF -p $PEDIGREE $GENE_LIST|$PERL $COMPOUNDHET -v - -p $PEDIGREE >  $CWD_VCF.tmp"
    $PERL $INHERITANCE -v $CWD_VCF -p $PEDIGREE $GENE_LIST|$PERL $COMPOUNDHET -v - -p $PEDIGREE $CH_OPTIONS >  $CWD_VCF.tmp
    END_NUM=`egrep -v "^#|^$" ${CWD_VCF}.tmp |wc -l|cut -f1 -d" "`
    if [ ! "$END_NUM" -ge "$START_NUM" ];
    then 
      log_error "${CWD_VCF} Inheritance script failed--expected at least $START_NUM lines, but only found $END_NUM" 
      exit 100
    fi
    mv $CWD_VCF.tmp $CWD_VCF
  fi
fi

#Add VCF Links for VCF miner
if [ -z "$LINKOFF" ]
then
  $PERL $LINKS -v $CWD_VCF | $PERL $TRIM -v - -o BaseQRankSum,ClippingRankSum,DS,END,FS,HaplotypeScore,InbreedingCoeff,MLEAC,MLEAF,MQRankSum,NEGATIVE_TRAIN_SITE,POSITIVE_TRAIN_SITE,QD,ReadPosRankSum,SOR,VQSLOD,set  > $CWD_VCF.tmp
  END_NUM=`egrep -v "^#|^$" ${CWD_VCF}.tmp |wc -l|cut -f1 -d" "`
  if [ ! "$END_NUM" -ge "$START_NUM" ];
  then 
    log_error "${CWD_VCF} Add Links script failed--expected at least $START_NUM lines, but only found $END_NUM" 
    exit 100
  fi	
  mv $CWD_VCF.tmp $CWD_VCF
fi

#Print out table
if [ "$table" != 0 ]
then
  log "Making table file"
  echo "$DRILLS"|tr ";" "\n"|awk '($1)' > drill.table	
  if [ "$runsnpeff" == "TRUE" ]
  then 
    echo -e "snpeff.Gene_name\nsnpeff.Amino_acid_change\nsnpeff.Transcript\nsnpeff.Exon\nsnpeff.Effect\nsnpeff.Effect_impact\nsnpeff.Amino_acid_change\nsnpeff.Codon_change" >> drill.table
  fi

  if [ "$runCAVA" == "TRUE" ];
  then 
    echo -e "CAVA_IMPACT\nCAVA_TYPE\nCAVA_GENE\nCAVA_ENST\nCAVA_TRINFO\nCAVA_LOC\nCAVA_CSN\nCAVA_CLASS\nCAVA_SO\nCAVA_ALTFLAG\nCAVA_ALTANN\nCAVA_ALTCLASS\nCAVA_DBSNP" >> drill.table
  fi

  log_debug "Drilling into the data"
  log "#######################################################"
fi    
