#!/usr/bin/env perl
use Switch;
#CAVA_parse
while (<>){
	if($_=~/^#/){
		print;
		next;
	}
	else{
		chomp;
		@INF=split(/\t/,$_);
		@INFO=split(/;/,$INF[7]);
		@NEW=();@NEW2=();@NON_CAVA=();
		for ($i=0 ; $i<=scalar(@INFO);$i++){
			checkForDup($INFO[$i]);
		}#Done with For loop
	}
	next if($_=~/^$/);
	@NEW = do { my %seen; grep { !$seen{$_}++ } @NEW };
	$INFO=join(";",@NON_CAVA);
	$INFO=join(";",$INFO,@NEW);
	$line=join("\t",@INF[0..6],$INFO,@INF[8..@INF]);
	$line=~s/\t$//;
	print $line."\n";
	if (@NEW2){
		@NEW2 = do { my %seen; grep { !$seen{$_}++ } @NEW2 };
		$INFO2=join(";",@NON_CAVA);
		$INFO2=join(";",$INFO2,@NEW2);
		$line2=join("\t",@INF[0..6],$INFO2,@INF[8..@INF]);
		$line2=~s/\t$//;
		print $line2."\n";
		}
		@NEW=();@NEW2=();
	}

sub checkForDup(){
	my ($key,$val)=split(/=/,$INFO[$i]);
	if ($key =~ /CAVA_TYPE|CAVA_GENE|CAVA_TRANSCRIPT|CAVA_GENEID|CAVA_TRINFO|CAVA_LOC|CAVA_CSN|CAVA_PROTPOS|CAVA_PROTREF|CAVA_PROTALT|CAVA_CLASS|CAVA_SO|CAVA_ALTFLAG|CAVA_ALTANN|CAVA_ALTCLASS|CAVA_ALTSO|CAVA_IMPACT|CAVA_DBSNP/){
		#print "My KEY=$key and my VAL is $val\n";
		#There are 2 genes here
		if ($val =~/:/){
			my @var=split(/:/,$val);
			my $var=join("=",$key,@var[0]);
			#print "Looking at var=$var\n";
			reCodeCAVA($var,1);
			my $var=join("=",$key,$var[1]);
			#print "Second one is =$var\t VAL=$val\n";
			reCodeCAVA($var,2);		
		}
		#There is only 1 gene
		else{
			reCodeCAVA($INFO[$i],1);
		}
	}else{
		#Make sure I keep previous annotations
		push(@NON_CAVA,$INFO[$i])
	}
	

}

sub reCodeCAVA(){
	my ($ANNO,$num)=@_;
	#Translate 1-3 into HIGH-LOW
	if ($ANNO =~ /CAVA_IMPACT=1/){$impact="CAVA_IMPACT=HIGH"}
	elsif($ANNO =~ /CAVA_IMPACT=2/){$impact="CAVA_IMPACT=MODERATE"}
	elsif($ANNO =~ /CAVA_IMPACT=3/){$impact="CAVA_IMPACT=LOW"}
	elsif($ANNO =~ /CAVA_IMPACT=\./){$impact="CAVA_IMPACT=LOW"}
	else{
		if($num==1){
			push(@NEW,$ANNO,$impact);
		}
		else{
			push(@NEW2,$ANNO,$impact);
		}
	}
}
