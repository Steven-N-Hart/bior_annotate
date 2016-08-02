# bior_annotate

### Prerequisties

#### Install
```
git clone https://github.com/Steven-N-Hart/bior_annotate.git
git checkout v2.7
cd bior_annotate/dockerFiles
```
#### Download Reference files
```
#Get human reference genome
curl -o references/hg19.fa.gz ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz 
bgzip -dc references/hg19.fa.gz > references/hg19.fa
samtools faidx references/hg19.fa

#Now get the test VCF File
curl -# -O 
```
#### Get bior catalogs 
```
mkdir catalogs && cd catalogs
# Download the 1000 genomes catalog
curl -# -O https://s3-us-west-2.amazonaws.com/mayo-bic-tools/bior_annotate/catalogs/chr17/1000_genomes_chr17.tar.gz
# Download the ClinVar catalog
curl -# -O https://s3-us-west-2.amazonaws.com/mayo-bic-tools/bior_annotate/catalogs/chr17/ClinVar_chr17.tar.gz
# Download the Exome Sequencing Project catalog
curl -# -O https://s3-us-west-2.amazonaws.com/mayo-bic-tools/bior_annotate/catalogs/chr17/ESP_chr17.tar.gz
# Download the dbSNP catalog
curl -# -O https://s3-us-west-2.amazonaws.com/mayo-bic-tools/bior_annotate/catalogs/chr17/dbSNP_chr17.tar.gz

# Now unzip the catalogs
for x in *tar.gz
do
  tar xvzf $x
  rm $x
done

#Change back to the home directory
cd ..
```
Your `catalogs` directory should now look like this:
```
1000_genomes/
    20130502_GRCh37/
        variants_nodups.v1/
            ALL.wgs.sites.vcf.columns.tsv
            ALL.wgs.sites.vcf.datasource.properties
            ALL.wgs.sites.vcf.tsv.bgz
            ALL.wgs.sites.vcf.tsv.bgz.tbi

ClinVar/
    20160515_GRCh37/
        variants_nodups.v1/
            macarthur-lab_xml_txt.columns.tsv
            macarthur-lab_xml_txt.columns.tsv.blacklist #Note: this file is not used here
            macarthur-lab_xml_txt.columns.tsv.blacklist.biorweb #Note: this file is not used here
            macarthur-lab_xml_txt.datasource.properties
            macarthur-lab_xml_txt.tsv.bgz
            macarthur-lab_xml_txt.tsv.bgz.tbi

dbSNP/
    139/
        chr17_GRCh37.columns.tsv
        chr17_GRCh37.datasource.properties
        chr17_GRCh37.tsv.bgz
        chr17_GRCh37.tsv.bgz.tbi
    142_GRCh37.p13/
        variants_nodups.v1
            chr17.vcf.columns.tsv
            chr17.vcf.datasource.properties
            chr17.vcf.tsv.bgz
            chr17.vcf.tsv.bgz.tbi
ESP/
    V2_GRCh37/
        variants.nodups.v1/
            ESP6500.vcf.columns.tsv
            ESP6500.vcf.datasource.properties
            ESP6500.vcf.tsv.bgz
            ESP6500.vcf.tsv.bgz.tbi
```
#### Setup/Install docker environment
```
docker build -t stevenhart/bior_annotate:latest dockerFiles/
```
#### Launch docker
```
docker run -it --name bior --rm -v $PWD:/Data -w /Data stevenhart/bior_annotate:latest
```
* Note for windows, you will need to use  
```
docker run -it --rm -v //c/path/to/bior_annotate:/Data stevenhart/bior_annotate:latest
```

#### Run the demo
```
sh trunk/bior_annotate.sh -v trunk/test.vcf -c dockerFiles/catalogFile.docker -d dockerFiles/drillFile.docker -T dockerFiles/tool_info.minimal.txt -o TEST  -M trunk/config/memory_info.txt -Q NA 
```


