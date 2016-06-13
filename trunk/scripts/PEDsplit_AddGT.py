###################################################################################################################################################
##Usage - python new_PED_and_add_genotype_with_GATK_step_1-18.py VCF-6.vcf PED_6 OUT_PED_3 OUT_VCF3samples_INFO_modified.vcf 
##VCF-6.vcf - VCF file that is generated from genomeGPS pipeline with both trio families
##PED_6 - PED file that contains INFO about all 6 samples(both trio families)
##OUT_PED_3 - Output PED file where the control samples(control trio family) have been trimmed
##OUT_VCF3samples_INFO_modified.vcf- Output VCF file(one trio family) that is generated after genotype infomration has been added to the INFO field
##tool_info -tool_info as given in config files
###################################################################################################################################################

import sys, re
from subprocess import Popen, PIPE
import os.path

def GetArgs():
	for string in sys.argv:
		print "ARG = " + string
	VCF6samples=sys.argv[1]
	(TMP_DIR, FILENAME)=os.path.split(VCF6samples)
	PED_file=open(sys.argv[2], 'r')
	PED=PED_file.readlines()
	tool=open(sys.argv[5], 'r')
	toolinfo=tool.readlines()
	PED_out=open(sys.argv[3], "w")
	out=open(sys.argv[4], 'w')      
	
	return (VCF6samples,TMP_DIR,PED,toolinfo,PED_out,out)
	
def main():
	VCF6samples,TMP_DIR,PED,toolinfo,PED_out,out = GetArgs()
	dad,mom,child,PEDSamples = ProcessPED(TMP_DIR,PED,PED_out)
	ref_path,GATK_path,JAVA = ProcessToolInfo(toolinfo,VCF6samples,TMP_DIR)
	SelectVariantsOutput = RunSelectVariants(JAVA,GATK_path,ref_path,VCF6samples,TMP_DIR)
	WriteOutput(SelectVariantsOutput,dad,mom,child,PEDSamples,out)
	
def ProcessPED(TMP_DIR,PED,PED_out):
	exclude_samples=open(TMP_DIR + "/exclude_samples.txt", 'w')
	PEDSamples = {}
	dad=''
	mom=''
	child=''
	for i in PED:
		i=i.split()
		if i[0]=="CONTROLFAMILY":
			exclude_samples.write(i[1]+"\n")
		else:
			if i[2] not in "0":
				PEDSamples[i[1]] = "PRO"
				child+=i[1]
			else:
				if int(i[4]) == 1:
					PEDSamples[i[1]] = "DAD"
					dad+=i[1]
				else:
					PEDSamples[i[1]] = "MOM"
					mom+=i[1]
			for eachField in i:
				PED_out.write(eachField+"\t")  	
				PED_out.write("\n")
	exclude_samples.close()	

	if dad=='':
		print "\nPlease check PED file. Dad sample name not found, Script terminated\n\n"
		exit()
	if mom=='':
		print "\nPlease check PED file. Mom sample name not found, Script terminated\n\n"
		exit()
	if child=='':
		print "\nPlease check PED file. Child sample name not found, Script terminated\n\n"
		exit()
		
	return (dad,mom,child,PEDSamples)

def ProcessToolInfo(toolinfo,VCF6samples,TMP_DIR):
	ref_path=None
	GATK_path=None
	JAVA=None
	
	for i in toolinfo:
		if i.startswith("REF_GENOME"):
			ref_path=re.findall(r'\"(.+?)\"', i)
			ref_path=ref_path[0]
		elif i.startswith("GATK="):
			GATK_path=re.findall(r'\"(.+?)\"', i)
			GATK_path=GATK_path[0]
		elif i.startswith("JAVA7="):
			JAVA=re.findall(r'\"(.+?)\"', i)
			JAVA=JAVA[0] + '/java'
	
	print "ref_path=" + ref_path
	print "GATK_path=" + GATK_path
	print "JAVA=" + JAVA
	print JAVA+ ' -Xmx1G '+ '-jar '+ GATK_path + '/GenomeAnalysisTK.jar '+ '-K /biotools/biotools/gatk/current/volety.rama_mayo.edu.key '+ '-et '+ 'NO_ET '+ '-T '+ 'SelectVariants '+ '-R '+ ref_path+ ' --variant '+ VCF6samples+ ' -o '+TMP_DIR + '/VCF-3_no_genotype.vcf '+ '-xl_sf '+ TMP_DIR + '/exclude_samples.txt '+ '-env '
		
	return (ref_path,GATK_path,JAVA)

def RunSelectVariants(JAVA,GATK_path,ref_path,VCF6samples,TMP_DIR):
	process = Popen([JAVA, '-Xmx1G', '-jar', GATK_path + '/GenomeAnalysisTK.jar', '-K', '/biotools/biotools/gatk/current/volety.rama_mayo.edu.key', '-et', 'NO_ET', '-T', 'SelectVariants', '-R', ref_path, '--variant', VCF6samples, '-o',TMP_DIR + '/VCF-3_no_genotype.vcf', '-xl_sf', TMP_DIR + '/exclude_samples.txt', '-env'], stdout=PIPE, stderr=PIPE)
	out_popen=process.communicate()
	print out_popen
	SelectVariantsOutput=open(TMP_DIR + "/VCF-3_no_genotype.vcf", "r")
	return SelectVariantsOutput

def WriteOutput(SelectVariantsOutput,dad,mom,child,PEDSamples,out):
	ReqMomGT = 0
	ReqDadGT = 0
	ReqProGT = 0
	for line in SelectVariantsOutput:                      
		line=line.split()
		if line[0]=="#CHROM":
			if PEDSamples[line[-1]] == "MOM":
				ReqMomGT = -1
			if PEDSamples[line[-1]] == "DAD":
				ReqDadGT = -1
			if PEDSamples[line[-1]] == "PRO":
				ReqProGT = -1
			if PEDSamples[line[-2]] == "MOM":
				ReqMomGT = -2
			if PEDSamples[line[-2]] == "DAD":
				ReqDadGT = -2
			if PEDSamples[line[-2]] == "PRO":
				ReqProGT = -2
			if PEDSamples[line[-3]] == "MOM":
				ReqMomGT = -3
			elif PEDSamples[line[-3]] == "DAD":
				ReqDadGT = -3
			elif PEDSamples[line[-3]] == "PRO":
				ReqProGT = -3
			
			out.write("##INFO=<ID="+child+"_GT,Number=1,Type=String,Description="+'"'+"Child Genotype"+'">'+"\n")
			out.write("##INFO=<ID="+mom+"_GT,Number=1,Type=String,Description="+'"'+"Mom Genotype"+'">'+"\n")
			out.write("##INFO=<ID="+dad+"_GT,Number=1,Type=String,Description="+'"'+"Dad Genotype"+'">'+"\n")

			for i in line:         
				out.write(i+"\t")
		elif line[0].startswith("#") and line[0]!="#CHROM":     
			for i in line:
				out.write(i+" ")

		else:
			GT=child+"_GT="+line[ReqProGT][0:3]+";"+mom+"_GT="+line[ReqMomGT][0:3]+";"+dad+"_GT="+line[ReqDadGT][0:3]
			for i in range(len(line)):
				if int(i) <= 6:
					out.write(line[i]+"\t")
				if i == 7:
					out.write(line[i]+";"+GT+"\t")
				if i>=8:
					out.write(line[i]+"\t")
		out.write("\n")
	return 0
	
if __name__ == '__main__':
    main()
