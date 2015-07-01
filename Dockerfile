FROM centos:6
MAINTAINER Steven N Hart, PhD
#docker run -it -v /Users/m087494/Desktop/Docker/Data:/home/Data stevenhart/bior_annotate:latest

RUN yum install -y \
	autoconf \
	automake \
	bzip2 \
	cpan \
	finger \
	gcc \
	gcc-c++ \
	git \
	java-1.7.0-openjdk \
	java-1.7.0-openjdk-devel \
	kernel-devel \
	make \
	ncurses-devel \
	ncurses \
	python-devel \
	tar \
	unzip \
	wget \
	zlib-devel 

RUN cd /home

RUN git clone https://github.com/samtools/htslib.git 
RUN cd htslib && make && make install

#Install BioR
RUN cd /
RUN wget https://s3-us-west-2.amazonaws.com/mayo-bic-tools/bior/bior_2.1.1.tar.gz \
	&& tar xvzf bior_2.1.1.tar.gz  \
	&& cp bior_2.1.1/bin/* /usr/bin/ \
	&& rm -f bior_2.1.1.tar.gz
ENV BIOR_LITE_HOME=/bior_2.1.1/
RUN echo -e "BIOR_LITE_HOME=/home/bior_2.1.1/\nexport $BIOR_LITE_HOME" > bior_2.1.1/PKG_PROFILE

#Install SAMtools
RUN git clone https://github.com/samtools/samtools.git
RUN cd samtools && make && make install
RUN cd /
ENV PATH=$PATH:/samtools/

#####################################################
# Install perl modules
#####################################################

RUN cpan -i Data::Dumper Getopt::Long List::MoreUtils Switch 

#####################################################
# Install Cava
#####################################################

RUN wget https://pypi.python.org/packages/source/p/pysam/pysam-0.8.3.tar.gz#md5=b1ae2a8ec3c6d20be30b2bc1aa995bbf
RUN wget https://bootstrap.pypa.io/ez_setup.py -O - | python

RUN tar xvzf pysam-0.8.3.tar.gz \
	&& cd pysam-0.8.3 \
	&& python setup.py build \
	&& python setup.py install
RUN cd /
RUN rm pysam-0.8.3.tar.gz

RUN wget http://www.well.ox.ac.uk/bioinformatics/Software/Cava-full-latest.tgz
RUN tar xvzf Cava-full-latest.tgz
RUN rm Cava-full-latest.tgz
RUN cd cava-v1.0.0/
RUN wget -O cava-v1.0.0/hg19.fa.gz ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz 
RUN wget -O cava-v1.0.0/hg19.fa.gz.fai ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz.fai
RUN perl -pi -e 's/hg19.fa/hs37d5.fa.gz/' cava-v1.0.0/config.txt
RUN cd /

#####################################################
# Install SNPEFF
#####################################################
RUN wget http://sourceforge.net/projects/snpeff/files/snpEff_latest_core.zip
RUN unzip snpEff_latest_core.zip
RUN rm snpEff_latest_core.zip

#####################################################
# Get VCF File
#####################################################
RUN wget https://s3-us-west-2.amazonaws.com/mayo-bic-tools/variant_miner/vcfs/HG00098.vcf.gz

#####################################################
# Get bior_annotate
#####################################################
#git-svn clone --username m087494  https://bsisvn.mayo.edu/main/personal/hart_steven_m087494/bior_annotate/trunk



#https://github.com/arq5x/bedtools2.git




