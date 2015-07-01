# bior_annotate

### Prerequisties
#### Download Reference files
curl -o references/hg19.fa.gz ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz 
curl -o references/hg19.fa.gz.fai ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz.fai



### Setup/Install
```
$ docker build -t stevenhart/bior_annotate:latest .
```
### Launch
```
$ docker run -it --rm -v `pwd`:/Data stevenhart/bior_annotate:latest
$ sh Data/trunk/bior_annotate.sh -v /Data/HG00098.vcf.gz -c Data/catalogFile.docker -d Data/drillFile.docker -T /Data/tool_info.minimal.txt -o TEST  -M Data/trunk/config/memory_info.txt -l
Options specified: -v /Data/HG00098.vcf.gz -c Data/catalogFile.docker -d Data/drillFile.docker -T /Data/tool_info.minimal.txt -o TEST -M Data/trunk/config/memory_info.txt -l
```
> Make sure `pwd` contains the following elements


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
				Protocol.sh
