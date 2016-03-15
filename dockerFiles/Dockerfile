FROM centos:6
MAINTAINER Steven N Hart, PhD
#docker run -it -v /Users/m087494/Desktop/Docker/Data:/home/Data stevenhart/bior_annotate:latest

RUN yum update -y
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
	which \
	wget \
	zlib-devel 


#####################################################
# Install htslib
#####################################################
RUN git clone https://github.com/samtools/htslib.git 
RUN cd htslib && make && make install

#####################################################
# Install BIOR
#####################################################
RUN cd /
RUN wget https://s3-us-west-2.amazonaws.com/mayo-bic-tools/bior/bior_2.1.1.tar.gz \
	&& tar xvzf bior_2.1.1.tar.gz  \
	&& rm -f bior_2.1.1.tar.gz
ENV PATH=$PATH:/bior_2.1.1/bin
ENV BIOR_LITE_HOME=/bior_2.1.1
RUN echo "export BIOR_LITE_HOME=/bior_2.1.1" > bior_2.1.1/PKG_PROFILE


#####################################################
# Install SAMtools
#####################################################
RUN cd / 
RUN git clone https://github.com/samtools/samtools.git
RUN cd samtools && make && make install && cd /
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
	&& python setup.py install \
	&& cd /
RUN rm pysam-0.8.3.tar.gz

RUN wget http://www.well.ox.ac.uk/bioinformatics/Software/Cava-full-latest.tgz
RUN tar xvzf Cava-full-latest.tgz
RUN rm Cava-full-latest.tgz
RUN cd cava-v1.0.0/
RUN perl -pi -e 's/hg19.fa/\/Data\/references\/hg19.fa/;s/exome_65_GRCh37.gz/\/cava-v1.0.0\/exome_65_GRCh37.gz/;s/dbSNP138.gz/\./' cava-v1.0.0/config.txt
RUN cd /

#####################################################
# Install SNPEFF
#####################################################
RUN wget http://sourceforge.net/projects/snpeff/files/snpEff_latest_core.zip
RUN unzip snpEff_latest_core.zip
RUN rm snpEff_latest_core.zip

#####################################################
# Get BEDtools
#####################################################
RUN git clone https://github.com/arq5x/bedtools2.git
RUN cd /bedtools2/ && make && make install && cd /
ENV PATH=$PATH:/bedtools2/bin




