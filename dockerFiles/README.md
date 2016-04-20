# bior_annotate

### Prerequisties

#### Install
```
git clone https://github.com/Steven-N-Hart/bior_annotate.git
git checkout v2.7
cd bior_annotate
```
#### Download Reference files
```
#Get human reference genome
curl -o references/hg19.fa.gz ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz 
bgzip -dc references/hg19.fa.gz > references/hg19.fa
samtools faidx references/hg19.fa


#Get bior folder

```
> For this demo, make sure your current working directory contains the following elements
``` 
 references/
    hg19.fa.gz
    hg19.fa.gz.fai

catalogs/
  2015_05_18/
    noTCGA_ExAc.datasource.properties
    noTCGA_ExAc.columns.tsv
    noTCGA_ExAc.tsv.bgz.tbi
    noTCGA_ExAc.tsv.bgz
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


