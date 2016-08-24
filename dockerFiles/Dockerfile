FROM centos:latest
MAINTAINER Steven N Hart, PhD

RUN yum update -y
RUN yum install -y \
	autoconf \
	automake \
	bzip2 \
	perl-CPAN \
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
# Install perl modules
#####################################################

# Note there is an issue with CPAN here.  When you load the first time, it fails
# just try again and it's fine
RUN cpan -fi Data::Dumper Getopt::Long List::MoreUtils || echo "Did not pass the first time"
RUN cpan -fi Data::Dumper Getopt::Long List::MoreUtils 
RUN cpan Switch 

#####################################################
# Install htslib
#####################################################
RUN git clone https://github.com/samtools/htslib.git 
RUN cd htslib && make && make install

#####################################################
# Install BIOR
#####################################################
RUN cd /
RUN wget https://s3-us-west-2.amazonaws.com/mayo-bic-tools/bior/ToolkitDownloads/bior_4.1.1.zip 
RUN unzip bior_4.1.1.zip
RUN rm -f bior_4.1.1.zip
ENV PATH=$PATH:/bior_pipeline-4.1.1/bin
ENV BIOR_LITE_HOME=/bior_pipeline-4.1.1
RUN echo "export BIOR_LITE_HOME=/bior_pipeline-4.1.1" > bior_pipeline-4.1.1/PKG_PROFILE


#####################################################
# Install SAMtools
#####################################################
RUN git clone https://github.com/samtools/samtools.git
RUN cd samtools && make && make install && cd /
ENV PATH=$PATH:/samtools/



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
RUN rm -f pysam-0.8.3.tar.gz

RUN wget http://www.well.ox.ac.uk/bioinformatics/Software/Cava-full-latest.tgz
RUN tar xvzf Cava-full-latest.tgz
RUN rm -f Cava-full-latest.tgz
RUN perl -pi -e 's/human_g1k_v37.fasta/\/Data\/references\/hg19.fa/;s/exome_65_GRCh37.gz/\/cava-v1.1.1\/exome_65_GRCh37.gz/;s/dbSNP138.gz/\./' cava-v1.1.1/config.txt

#####################################################
# Install SNPEFF
#####################################################
RUN wget http://sourceforge.net/projects/snpeff/files/snpEff_latest_core.zip
RUN unzip snpEff_latest_core.zip
RUN rm -f snpEff_latest_core.zip

#####################################################
# Get BEDtools
#####################################################
RUN wget https://github.com/arq5x/bedtools2/releases/download/v2.26.0/bedtools-2.26.0.tar.gz
RUN tar xvzf bedtools-2.26.0.tar.gz && cd bedtools2 && make && make install && cd /
RUN rm -f bedtools-2.26.0.tar.gz 
ENV PATH=$PATH:/bedtools2/bin


#####################################################
# Get bior_annotate
#####################################################
RUN wget https://github.com/Steven-N-Hart/bior_annotate/archive/v2.8.4.tar.gz
RUN tar -xvzf v2.8.4.tar.gz
RUN rm -f 2.8.4.tar.gz
ENV PATH=$PATH:/bior_annotate-2.8.4/trunk/
RUN perl -p -i -e 's/\/data5\/bsi\/bictools\/scripts\/bior_annotate\/trunk\/trunk\//\/bior_annotate-2.8.4\/trunk\//' /bior_annotate-2.8.4/trunk/config/tool_info.txt 


