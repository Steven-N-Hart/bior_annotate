use List::MoreUtils;
my @VALUES=();
#open file
open(VCF,"$ARGV[0]") or die "must specify VCF file\n\n
Usage: 
perl SNPEFF_parse.pl test.vcf > results.out

";

while (<VCF>) {
    #Some versions of SNPEFF have trailing whitespaces.
    $_=~s/ $//;
	$tx="";
    #skip headers
    if ($_=~/^##/){
		if ($_=~/##INFO=<ID=EFF/) {
			$_=~s/ \"/\"/g;
			$_=~s/\" /\"/g;
			$_=~s/\(/\|/;
			$_=~s/\)//;
			print;
			chomp;
			#my @string=split(/\(/,$_);
			@string=split(/\'/,$_);
			$string=$string[1];
			$string=~s/\[|\]| //g;
			$string=~s/=EFF=/=/;
			@VALUES=split(/\|/,$string);
			#print "\n\nVALUES=@VALUES\n";
			#print out proper headers for them
			for ($j=0;$j<@VALUES;$j++){       
				$string="##INFO=<ID=snpeff.$VALUES[$j],Number=1,Type=String,Description=\"Annotation from SNPEFF\">\n";
				print $string;
			}
			next;
		}
        if ($_=~/##INFO=<ID=ANN/) {
			$_=~s/ \"/\"/g;
            $_=~s/\" /\"/g;
			#$_=~s/\//-/g;
            print;
            chomp;
            $_=~s/ |\'|\"|>//g;
			@VALUES=split(/\|/,$_);
            #print out proper headers for them
            for ($j=1;$j<@VALUES;$j++){
				$string="##INFO=<ID=snpeff.$VALUES[$j],Number=1,Type=String,Description=\"Annotation from SNPEFF\">\n";
				#if($VALUES[$j] == "Feature_Type"){$tx=$j}             
				print $string;
            }
            next;
        }		
		else{
			$_=~s/ \"/\"/g;
			$_=~s/\" /\"/g;
			print;
			next;
		}
    }
    #Get sample names
    elsif ($_=~/^#CHROM/) {
		print;
		next;
    }      
    else{
        #Extract info
		next if ($_=~/^#/);
        chomp;
        my @ROW=split(/\t/,$_);
		my $len=scalar(@ROW)-1;
		#print "ROW==@ROW\n\nLENGTH=$len\n\n";die;
        my @INFO=split(/;/,$ROW[7]);
		#Use this for the snpeff corrected
		my $new_INFO="";
		#use this to store everything else
		my $old_INFO="";
		my $try="";
		@EFF=();
        for (my $i=0;$i<@INFO;$i++){
			my $tag=$INFO[$i];$tag=~s/;;/;/g;
			#If INFO doesn't match EFF, then add to new		
			if($tag=~/ANN=|EFF=/){
				$tag=~s/\(/\|/g;
				$tag=~s/\)//g;
				@alternateResults=split(/,/,$tag);
				#print join("\n",@alternateResults)."\n";
				for ($j=0;$j<@alternateResults;$j++){
					#SNPEff ANN annotates sequence features other than transcripts, so make sue to only output transcripts
					# Otherwise, you have a lot of duplication
					#next if (( $tag=~/^ANN/) & ($alternateResults[$j] !~/transcript/));
					@entries=split(/\|/,$alternateResults[$j]);
					for (my $i=1;$i<@entries;$i++){
						#Only push it if it has a value
						if($entries[$i]){
							$new_INFO.="snpeff.".$VALUES[$i]."=".$entries[$i].";";
						}
                    }
					push(@EFF,$new_INFO);
				 }
			}
			else{
				#print "TAG=$tag\n";
				if($tag=~/^LOF=/){$tag="LOF=true"}
				if($tag=~/^NMD=/){$tag="NMD=true"}
				$old_INFO.=$tag.";";
			}
		}
	#print "new_INFO=$new_INFO\nold_info=$old_INFO\n";
	for ($i=0;$i<@EFF;$i++){
		$var=join(";",$old_INFO,$EFF[$i]);
		$line=join ("\t",@ROW[0..6],$var,@ROW[8..$len])."\n";
		#$line=~s/\t\n/\n/;
		$line=~s/;;/;/g;
		print $line;
		}
	}
}
close VCF;
