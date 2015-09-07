# bior_annotate

### Prerequisties
#### Download Reference files
`curl -o references/hg19.fa.gz ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz `  
`gunzip references/hg19.fa.gz > references/hg19.fa`  
`samtools faidx references/hg19.fa`


### Setup/Install
```
$ docker build -t stevenhart/bior_annotate:latest .
```
### Launch
```
$ docker run -it --rm -v $PWD:/Data stevenhart/bior_annotate:latest
$ cd Data
$ sh trunk/bior_annotate.sh -v HG00098.vcf.gz -c catalogFile.docker -d drillFile.docker -T tool_info.minimal.txt -o TEST  -M trunk/config/memory_info.txt -l
```
* Note for windows, you will need to use  
`$ docker run -it --rm -v //c/UserS/m087494/Desktop/bior_annotate:/Data stevenhart/bior_annotate:latest`  

> For this demo, make sure `pwd` contains the following elements

```
Data/  
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
