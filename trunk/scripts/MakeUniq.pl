#!/usr/bin/env perl
BEGIN{$chr="chr";$pos=0;$ref="N";$alt="N";$count=0};
while (<>){
	if($_=~/^#/){print;next}
	chomp; 
	s/\t\n/\n/;
	s/==/=/g;
	s/\t;/\t/;
	($CHR,$POS,$ID,$REF,$ALT,@LINE)=split("\t",$_);
	#print STDERR "$CHR==$chr && $POS==$pos && $REF eq $ref && $ALT eq $alt &&!(eof)\n";
	next if($CHR==$chr && $POS==$pos && $REF eq $ref && $ALT eq $alt); 
	$chr=$CHR;$pos=$POS;$ref=$REF;$alt=$ALT; 
	print "$_\n";$count++
}
END{print STDERR "Found $count unique records\n"}
