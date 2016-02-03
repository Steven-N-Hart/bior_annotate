#!/usr/bin/perl 
use Getopt::Long;
use List::MoreUtils qw(uniq);
##fix
my ($pedFile,$vcf,$help,$verbose);
GetOptions(
        'vcf|v=s' => \$vcf,
		'help|h' => \$help,
		'verbose' => \$verbose
);

if($help){&usage();}

open (VCF,"$vcf") or die "Can't open VCF\n";
	while (<VCF>){
		if ($_ =~/^##/){
			#$_=~s/Number=1|Number=A/Number=./;
			print;
			next
		}
		elsif($_ =~/^#CHROM/){
			#print "##INFO=<ID=Link_Omim,Number=1,Type=String,Description=\"Hyperlink to OMIM\">\n";
			print "##INFO=<ID=Link_dbSNP,Number=1,Type=String,Description=\"Hyperlink to dbSNP\">\n";
			print "##INFO=<ID=Link_GeneCards,Number=1,Type=String,Description=\"Hyperlink to Genecards\">\n";
			print "##INFO=<ID=Link_IGV,Number=1,Type=String,Description=\"If IGV is open, this will take you to that locus\">\n";
			print "##INFO=<ID=Link_Pubmed,Number=1,Type=String,Description=\"Takes you to pubmed entries used for HGMD classfication\">\n";
			print "##INFO=<ID=Link_GoogleSearch,Number=1,Type=String,Description=\"Performs a google search of the HGVS nomenclature\">\n";
			print "##INFO=<ID=Link_Clinvar,Number=1,Type=String,Description=\"Performs a clinvar search of the CLINVAR terms\">\n";
			print;
			next;
		}
		else{
			next if($_=~/^$/);
			chomp;
			@line=split("\t",$_);
			@INFO=split(/;/,@line[7]);
			@NEW=();$new="";@tmp=();$HGVS="";$GENE="";@rsIDs=();$ClinvarSIG="";
			for ($i=0 ; $i<scalar(@INFO);$i++){
				#print "I=$INFO[$i]\n";
				#rsID
				 ##http://www.ncbi.nlm.nih.gov/projects/SNP/snp_ref.cgi?rs=28931606
				if ($INFO[$i] =~ /dbSNP/){
				#print "YES! there is a dbSNP!\n$INFO[$i]\n";die;
					@tmp=split("=",$INFO[$i]);
					@rsIDs=split(",",$tmp[1]);
					$j=0;
					foreach $rsID(@rsIDs){
						$number=$rsID;$number=~s/rs//;
						$new=qq(<a href="http://www.ncbi.nlm.nih.gov/projects/SNP/snp_ref.cgi?rs=$number" target="_blank">$rsID</a>);
						unless($i==scalar(@INFO)-1){$new=$new.","}
						if($j==0){$new="Link_dbSNP=$new"}
						$j++;
					}
					#print "My RSID=$new\n";
					push(@NEW,$INFO[$i],$new);
				}
				##http://www.genecards.org/cgi-bin/carddisp.pl?gene=KRAS
				elsif($INFO[$i] =~ /CAVA_GENE=/i){
					@tmp=split("=",$INFO[$i]);
					$tmp[1]=~s/\.//;
					if($tmp[1]){
					$new=qq(;Link_GeneCards=<a href="http://www.genecards.org/cgi-bin/carddisp.pl?gene=$tmp[1]" target="_blank">$tmp[1]</a>);
					$GENE=$tmp[1]};
					#print "My Gene=$new\n";
					push(@NEW,$INFO[$i],$new);
				}
				elsif(($INFO[$i] =~ /hgmd/i)&($INFO[$i] =~ /PubMed/i)){
					@tmp=split("=",$INFO[$i]);
					@PMID=split(",",$tmp[1]);
					$j=0;
					foreach $PMID(@PMID){
						$number=~$PMID;
						$new=qq(<a href="http://www.ncbi.nlm.nih.gov/pubmed/?term=$PMID" target="_blank">$PMID</a>);
						unless($i==scalar(@INFO)-1){$new=$new.","}
						if($j==0){$new="Link_Pubmed=$new"}
						$j++;
					}
					#print "My HGMD_pubmedID is $new\n";
					push(@NEW,$INFO[$i],$new);
				}
				elsif($INFO[$i] =~ /CAVA_CSN=/){
					@tmp=split("=",$INFO[$i]);
					@HGVS=split(/_p/,$tmp[1]);
					$HGVS=join("",@HGVS);
					#print "My HGVS=$HGVS\n";
					push(@NEW,$INFO[$i]);
				} 				
				elsif($INFO[$i] =~ /snpeff.Amino_Acid_Change=/){
					@tmp=split("=",$INFO[$i]);
					#If Savant already Set this, skip
					unless($HGVS){$HGVS=$tmp[1]};
					#print "My HGVS=$HGVS\n";
					push(@NEW,$INFO[$i]);
				}                                
				elsif($INFO[$i] =~ /.clinical_significance=/){
					@tmp=split("=",$INFO[$i]);
					$ClinvarSIG=$tmp[1];
					#print "My Gene=$new\n";
					push(@NEW,$INFO[$i]);
				}				
				else{
					push(@NEW,$INFO[$i])
				}
			}			
			$INFO=join(";",@NEW);
			
			if(($GENE)&&($HGVS)){
				@new=split(/ |\//,$HGVS);
				$link=qq(;Link_GoogleSearch=<a href="https://www.google.com/search?q=$GENE+$new[0]+$new[1]" target="_blank">Google It!</a>);
				$INFO=$INFO."$link";
				}
			##IGV session (must be open)
			$link=qq(<a href="http://localhost:60151/goto?locus=$line[0]:$line[1]">View</a>);
			$INFO="$INFO;Link_IGV=$link";
			#Translate clinvar
			#print "($ClinvarSIG)&($rsIDs[0])\n";
			if(($ClinvarSIG)&($rsIDs[0])){
				$link=qq(<a href="http://www.ncbi.nlm.nih.gov/clinvar?term=$rsIDs[0]" target="_blank">$ClinvarSIG</a> );
				$INFO="$INFO;".$link;
			}
			#print "MY New INFO=$INFO\n";
			$newLine=join("\t",@line[0..6],$INFO,@line[8..@line]);
			$newLine=~s/\t$//;$newLine=~s/,;/;/g;
			$newLine=~s/;;/;/g;
			print $newLine."\n";
		}
}


sub usage{
	print "
	AddLinksToVCF.pl -v <vcf> 

";
exit 1;
}
