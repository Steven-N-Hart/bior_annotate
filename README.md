

##########################################################################################################
##
## Script Options:
##   Required:
##      -o    Output file name [required] ***Name only, not PATH***
##      -v    path to the VCF to annotate     [required]
##   Optional:
##      -c    path to catalog file
##      -d    Path to the drill file
##      -h    Display this usage/help text
##      -j    job name for qsub command
##      -l    set logging
##      -L    Do not add links to VCF [default is set to TRUE]
##      -M    memory info file from GGPS
##      -n    Number of lines to split the data into  [default:20000]
##      -O    output directory [cwd]
##      -s    Flag to turn on SNPEFF
##      -a    Flag to turn off CAVA annotation
##      -Q    queue override (e.g. 1-day) [defaults to what is in the tool_info]
##      -t    Export table as well as VCF [1]
##                              Version 1: Seperate columns for Depth, GQ, AD, and GT per sample
##                              Version 2: First N columns like VCF, one colulmn containing sample names
##      -T    tool info file from GGPS
##      -x    path to temp directory [default: cwd]
##
##
##      Clinical specific options (DLMP use only)
##      -P    PEDIGREE file (for trios only, this will add extra annotations)
##      -g    GENE list (only used with pedigrees)



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

