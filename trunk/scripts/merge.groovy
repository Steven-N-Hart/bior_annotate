//===========================================================================================
// This is a script used in the bior_annotate.sh script
// Merges multiple chunked annotated VCFs with the FORMAT and SAMPLE columns from the original huge VCF.
// This relies on the splitter code to have previously added a lineNumBior=xxxx to each line in the INFO column (col8)
//
// Merged VCF:
//   - Lines 1-7 come from annotated VCF chunk
//   - Line 8 (INFO col) contains a merger of all key-value pairs from the original huge VCF and the small chunnked annotated VCFs
//   - Lines 9-x come from the original huge VCF
//===========================================================================================



import htsjdk.samtools.util.BlockCompressedInputStream;
import htsjdk.samtools.util.BlockCompressedOutputStream;
import java.util.zip.GZIPInputStream;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.assertFalse;


//---------------------------------------
// Run the test suite - TESTING ONLY
//---------------------------------------
//        runTestSuite()


if( args.length != 3 ) { 
  printUsage()
  System.exit(1)
}


//---------------------------------------
// Get inputs
//---------------------------------------
// The lineNum-to-samples tsv file
File lineNumToSamplesTsv   = new File(args[0])
// The directory containing the "*.anno" annotated pieces of the split VCF
File annotatedVcfsDir  = new File(args[1])
// The merged output VCF (bgzip'd)
File outputCombinedVcf = new File(args[2])

isFileExists(lineNumToSamplesTsv)
isDirExists(annotatedVcfsDir)

// Get all of the annotated vcf files (*.anno)
List<File> annotatedVcfFiles = getAnnotatedVcfFiles(annotatedVcfsDir)

// Make all output dirs
outputCombinedVcf.getParentFile().mkdirs()

mergeSamplesWithAnnotatedFiles(lineNumToSamplesTsv, annotatedVcfFiles, outputCombinedVcf)

println("Merge DONE.  Output at:  " + outputCombinedVcf.getCanonicalPath())


//------------------------------------------------------
class  LineReader {
  public String line = null
  public long lineNumData = 0
  public long lineNumTotal = 0
  public BufferedReader fileReader
  private boolean isEndOfFile = false
  
  Map<Integer,String> lineNumToLineMap = new LinkedHashMap<Integer, String>() {
    protected boolean removeEldestEntry(Map.Entry eldest) {
      final int MAX_ENTRIES = 200
      return size() > MAX_ENTRIES
    }
  }

  public LineReader(BufferedReader fileReader) {
    this.fileReader = fileReader
  }
  
  // Read the next line from the file, and increment lineNum 
  public void readNextLine() {
    if( isEndOfFile )
      return
      
    String s = null
    while( (s = fileReader.readLine()) != null ) {
      //print(".")
      if( s.startsWith("#") ) {
        lineNumTotal++
      } else {
        lineNumTotal++
        lineNumData++
        lineNumToLineMap.put(lineNumData, s)
        // Is a data line, so break out
        break
      }
    }
    
    if( s == null ) {
      isEndOfFile = true
      //println(">>>>>>>>>>>>>> HIT END OF FILE")
    }    
    //println("dataLine: " + this.lineNumData + ", totalLine: " + lineNumTotal + " ::: " + line)
  }
  
  public String readUntilLine(long lineNum) {
    //println("------>>>>")
    int mapSize = this.lineNumToLineMap.size()
    //println("  map size: " + mapSize)
    //List<String> keys = new ArrayList<String>(this.lineNumToLineMap.keySet())
    //if( mapSize > 0 ) {
    //  println("  first map idx: " + keys.get(0))
    //  println("  last map idx:  " + keys.get(mapSize-1))
    //}
  
	while( this.lineNumData < lineNum ) {
	  readNextLine()
	}
	String line = this.lineNumToLineMap.get(lineNum)
	if( line == null )
	  System.err.println("ERROR: Could not find data line # " + lineNum)
	//println("<<<<-------")
	return line
  }
}


//------------------------------------------------------
private void printUsage() {
  println("USAGE:")
  println("  merge <originalHugeVcf>  <annotatedVcf>  <outputCombinedVcf>")
  println("  WHERE:")
  println("    - originalHugeVcf  is the original VCF file that may contain a huge number of sample columns")
  println("    - annotatedVcf is the VCF that was cut to 8 columns, then annotated with BioR and has the annotations put into the INFO column")
  println("    - outputCombinedVcf is the output file to write to that will combine the BioR annotations")
  println("      from annotatedVcf with the sample columns from originalHugeVcf (along with any other columns after column 8, such as FORMAT)")
}

//------------------------------------------------------
private void isFileExists(File f) {
  println("Checking file existence: " + f.getCanonicalPath())
  if( ! f.exists() ) {
	final String MSG = "ERROR: file cannot be found!  [" + f.getCanonicalPath() + "]"
    System.err.println(MSG)
    throw new Exception(MSG)
  }

  if( ! f.isFile() ) {
	final String MSG = "ERROR: item is not a file:  [" + f.getCanonicalPath() + "]"
    System.err.println(MSG)
    throw new Exception(MSG)
  }
}


//------------------------------------------------------
private void isDirExists(File d) {
  println("Checking directory existence: " + d.getCanonicalPath())
  if( ! d.exists() ) {
	final String MSG = "ERROR: directory cannot be found!  [" + d.getCanonicalPath() + "]"
    System.err.println(MSG)
    throw new Exception(MSG)
  }

  if( ! d.isDirectory() ) {
	final String MSG = "ERROR: item is not a directory:  [" + d.getCanonicalPath() + "]"
    System.err.println(MSG)
    throw new Exception(MSG)
  }
}

//------------------------------------------------------
private List<File> getAnnotatedVcfFiles(File annotatedVcfsDir) {
  List<File> annotatedVcfChunks = Arrays.asList(annotatedVcfsDir.listFiles( new FilenameFilter() {
    public boolean accept(File f, String filename) {
      return filename.endsWith(".anno")
    }
  }))
  Collections.sort(annotatedVcfChunks)
  return annotatedVcfChunks
}

//------------------------------------------------------
private void mergeSamplesWithAnnotatedFiles(File lineNumToSampleTsv, List<File> annotatedVcfFiles, File outputCombinedVcf) {

  //------------------------------------------------------------------------------------
  // NOTE: In the final version, we should add all header metadata lines ("##...") from both the original and annotation files
  //       into a HashSet and sort them by type.  
  // NOTE: The final splitter code should remove these lines are they will not be relevant until merging: ##SAMPLE, ##FORMAT, ##contig (??)
  // .............. 
  // NOTE: The final version of the splitter should add a "BiorLineId=1", etc to each line which we can use in the merge
  //       Instead of trying to have the first 7 columns match
  //------------------------------------------------------------------------------------


  // Get writer for output
  BlockCompressedOutputStream outWriter = getBgzipWriter(outputCombinedVcf)

  writeCombinedHeaders(outWriter, lineNumToSampleTsv, annotatedVcfFiles.get(0))
  
  // Get reader for sample tsv file with HUGE # of columns VCF
  BufferedReader sampleReader = getBufferedReader(lineNumToSampleTsv)
  LineReader sampleLineReader = new LineReader(sampleReader)
  
  // Loop thru each of #'d output annotated files, and merge each line with the original VCF's INFO col and all FORMAT and SAMPLE cols
  //println("Merging samples tsv with annotated VCF: " + lineNumToSampleTsv.getCanonicalPath() + " with:")
  for(File annotatedVcfChunkFile : annotatedVcfFiles) {
    //println("  - " + annotatedVcfChunkFile.getCanonicalPath())
    writeMergedSamplesWithAnnotatedChunk(outWriter, annotatedVcfChunkFile, sampleLineReader)
  }
  
  sampleReader.close()
  outWriter.close()
}
  
//------------------------------------------------------
// Merge the lines from the current annotated file with the original VCF.  When done, return the last line read from the original VCF so we can start with that on the next file
// annotated file: - ex: #CHROM .... INFO
// samples file:   - ex: #LineNum  INFO  FORMAT  SAMPLE1  SAMPLE2....
private String writeMergedSamplesWithAnnotatedChunk(BlockCompressedOutputStream outWriter,  File annotatedVcfChunkFile,  LineReader sampleReader) {
  // Get reader for annotated VCF (just the 8 cols)
  BufferedReader annotatedVcfReader = getBufferedReader(annotatedVcfChunkFile)

  String annotatedLine = null
  while( (annotatedLine = annotatedVcfReader.readLine()) != null ) {
    // Skip header lines
    if( annotatedLine.startsWith("#") )
      continue;
    
    long lineNum  = getBiorLineNumFromInfo(annotatedLine)
    //println()
    //println("----------------------------")
    //println("LineNum: " + lineNum)
    //println("----------------------------")
    String sampleLine = sampleReader.readUntilLine(lineNum)
    String mergedLine = mergeLine(annotatedLine, sampleLine)
    
    //println()
    //println("      annot: " + annotatedLine)
    //println("---")
    //println("      orig:  " + (sampleLine.startsWith("chr") ? sampleLine.substring(3) : sampleLine))
    //println("---")
    //println("      merge: " + mergedLine)
    
    outWriter.write( (mergedLine + "\n").getBytes() )
  }

  annotatedVcfReader.close()
}
  
  
//------------------------------------------------------
private long getBiorLineNumFromInfo(String line) {
  final String LINE_NUM_STR = "lineNumBior="
  String infoCol = getCol(line, 8)
  int idx1 = infoCol.indexOf(LINE_NUM_STR)
  int idx2 = infoCol.indexOf(";", idx1)
  if( idx2 == -1 ) 
    idx2 = infoCol.length()
  String valStr = infoCol.substring(idx1 + LINE_NUM_STR.length(), idx2)
  return Long.parseLong(valStr)
}


  
//------------------------------------------------------
private void writeCombinedHeaders(BlockCompressedOutputStream outWriter,  File samplesFile,  File annotatedVcfChunk) {
  // Load all headers from the samplesFile into a set
  Set<String> headerLineSet = new HashSet<String>()
  
  headerLineSet.addAll(getHeaders(samplesFile))
  headerLineSet.addAll(getHeaders(annotatedVcfChunk))
  List<String> headersSorted = sortHeaders(headerLineSet)
  
  String columnHeaderAnnot   = getColumnHeader(annotatedVcfChunk)
  String columnHeaderSamples = getColumnHeader(samplesFile)
  String colHeader = mergeColHeader(columnHeaderAnnot, columnHeaderSamples)
  headersSorted.add(colHeader)
    
  // Output all the sorted headerLines plus the columnHeader
  for(String line : headersSorted) {
    outWriter.write( (line + "\n").getBytes() )
  }
}

//------------------------------------------------------
// colHeaderAnnot - ex:  #CHROM .... INFO
// colHeaderSamples- ex: #LineNum  INFO  FORMAT  SAMPLE1  SAMPLE2....
// OUTPUT:  #CHROM ... INFO  FORMAT  SAMPLE1  SAMPLE2....
// NOTE: The INFO column header exists in both lines
private String mergeColHeader(String colHeaderAnnot, String colHeaderSamples) {
  String formatAndSampleColHeaders = colHeaderSamples.replace("#DataLineNum\tINFO", "")
  return colHeaderAnnot + formatAndSampleColHeaders
}


//------------------------------------------------------
// Get only the "##" header lines
private List<String> getHeaders(File vcf) {
  BufferedReader vcfReader = getBufferedReader(vcf)
  String line = null
  List<String> headers = new ArrayList<String>()
  while( (line = vcfReader.readLine()) != null ) {
    if( line.startsWith("##") )
      headers.add(line)
    else
      break;
  } 
  vcfReader.close()
  return headers
}
  

//------------------------------------------------------
// Get only the "#CHROM" column header line
private String getColumnHeader(File vcf) {
  BufferedReader vcfReader = getBufferedReader(vcf)
  String colHeaderLine = null
  String line = null
  while( (line = vcfReader.readLine()) != null ) {
    if( line.startsWith("##") ) {
      continue  // skip metadata headers
    } else if( line.startsWith("#") ) {
	  colHeaderLine = line
	  break
	} else {
      break;
    }
  } 
  vcfReader.close()
  return colHeaderLine
}


//------------------------------------------------------
private List<String> sortHeaders(Set<String> headerSet) {
  List headerList = new ArrayList<String>(headerSet)
  Collections.sort(headerList, new Comparator<String>() {
    public int compare(String header1, String header2) {
      int diff = getHeaderSortIndex(header1) - getHeaderSortIndex(header2)
      // If the headers are different types, then return the difference, else do a string compare
      return  (diff != 0)  ?  diff  :  header1.compareToIgnoreCase(header2)
    }
  })
  return headerList
}


//------------------------------------------------------
private int getHeaderSortIndex(String headerLine) {
  List<String> HEADERS = Arrays.asList(
    "##fileformat=",
    "##fileDate=",
    "##source=",
    "##reference=",
    "##assembly=",
    "##contig=",
    "##phasing=",
    "##dictionary=",
    "##INFO=",
    "##ALT=",
    "##FILTER=",
    "##FORMAT=",
    "##META=",
    "##SAMPLE=",
    "##PEDIGREE=",
    "##pedigreeDB=",
    "##BIOR=",
    "#CHROM"
    )
  for(int i=0; i < HEADERS.size(); i++) {
    if( headerLine.startsWith(HEADERS.get(i)) )
      return i
  }
  // Not found, so return 1 past end of list
  return HEADERS.size() 
}


//------------------------------------------------------
private boolean isSameLine(String annotLine, String origLine) {
  origLine = removeChrPrefix(origLine)
  boolean isFirst4ColsSame = getFirst4Cols(annotLine).equals(getFirst4Cols(origLine))
  if( ! isFirst4ColsSame )
    return false
  
  // Else, if the first 4 were the same, then check the 5th col (ALTS),
  // which could be broken out into a comma-separated list in origLine,
  // but will be separate alts in annotLine
  String annotCol5 = getCol(annotLine, 5)
  String origCol5  = getCol(origLine, 5)
  if( origCol5.equals(annotCol5) )
    return true;
    
  // Else check if the annotAlt is a subset of the origAlts
  return isAnnotAltASubsetOfOriginal(annotCol5, origCol5)
}

//------------------------------------------------------
private boolean isAnnotAltASubsetOfOriginal(String annotAlt, String origAlts) {
  List<String> origAltList = Arrays.asList(origAlts.split(","))
  return origAltList.contains(annotAlt)
}

//------------------------------------------------------
private String removeChrPrefix(String s) {
  // If the string starts with "chr" then remove that
  if( s.toLowerCase().startsWith("chr") )
    s = s.substring(3)
  return s
}

//------------------------------------------------------
private String getFirstNonMetadataLine(BufferedReader fin) {
  String line = null;
  while( (line = fin.readLine()) != null  &&  line.startsWith("##") ) { }
  return line;
}
    
//------------------------------------------------------
private String getFirst4Cols(String s) {
  return getFirstXCols(s, 4)
}


//------------------------------------------------------
private String getFirst7Cols(String s) {
  return getFirstXCols(s, 7)
}

//------------------------------------------------------
// Get first X columns as a single string
private String getFirstXCols(String s, int numCols) {
  int count = 0;
  int idx = s.indexOf("\t")
  while( idx != -1 ) {
    count++
    if( count == numCols ) 
      return s.substring(0, idx)
    idx = s.indexOf("\t", idx+1)
  }
  // Must be less than numCols columns, so just return whole string
  return s;  
}

//------------------------------------------------------
// Return the 1-based column.  If the column is not found, return ""
//   Ex:  "1 2 3 4", col=3 will return "3"
//   Ex:  "1 2 3 4", col=5 will return ""
private String getCol(String s, int col) {
  int currentCol = 1
  int idxStart = 0
  int idxEnd   = getNextTabIdxOrEnd(s, 0) 
  while( currentCol < col  &&  idxEnd != s.length() ) {
    currentCol++
    idxStart = idxEnd + 1
    idxEnd = getNextTabIdxOrEnd(s, idxStart)
  }
  
  // If the correct column was found, then return it
  if( currentCol == col )
    return s.substring(idxStart, idxEnd)
    
  // Not found, so return ""
  return "";
}

//------------------------------------------------------
private int getNextTabIdxOrEnd(String s, int start) {
  int idx = s.indexOf("\t", start)
  if( idx == -1 ) 
    return s.length()
  return idx
}

//------------------------------------------------------
// Take lines 1-7 of lineAnnot;  then merge INFO columns from both(column 8);  then add lines 9-x from samplesLine
// annotated file: - ex: #CHROM .... INFO
// samples file:   - ex: #LineNum  INFO  FORMAT  SAMPLE1  SAMPLE2....
private String mergeLine(String lineAnnot, String samplesLine) {
  String annotFirst7 = getFirst7Cols(lineAnnot)

  String annotInfoCol = getCol(lineAnnot, 8)
  String origInfoCol  = getCol(samplesLine, 2)
  String combinedInfoCol = origInfoCol.equals(".")  ?  annotInfoCol  :  (origInfoCol + ";" + annotInfoCol)
  // Remove the LineNumBior=xxxx, and remove any dot values, which mean there was no value for that field (ex: "AT:'.'")
  combinedInfoCol = removeDotValues( removeBiorLineNum(combinedInfoCol))

  int idxTab1 = samplesLine.indexOf("\t")
  int idxTab2 = samplesLine.indexOf("\t", idxTab1+1)
  String origCols9ToX = samplesLine.substring(idxTab2+1)
  
  return annotFirst7  +  "\t"  +  combinedInfoCol  +  (origCols9ToX.length() > 0  ?  ("\t" + origCols9ToX)  :  "")
}


//------------------------------------------------------
// Remove any key-value pairs where the value is a dot (which means no value)
// Ex: "AC=1;TA=.;X=Y" --> "AC=1;X=Y"
private String removeDotValues(String s) {
  String[] keyValPairs = s.split(";")
  StringBuilder strOut = new StringBuilder();
  boolean isFirst = true
  for(String keyVal : keyValPairs) {
    if( keyVal.endsWith("=.") )
      continue;
    if( ! isFirst )
      strOut.append(";")
    strOut.append(keyVal)
    isFirst = false
  }
  
  // If blank (all values were dots), then set to dot
  if( strOut.toString().trim().length() == 0 )
    return "."
    
  return strOut.toString()
}

//------------------------------------------------------
// Remove html links that may interfere with vcf-validation
// Ex: "Link_dbSNP=<a href="http://www.ncbi.nlm.nih.gov/projects/SNP/snp_ref.cgi?rs=75025155" target="_blank">rs75025155</a>"
// to:
//     "Link_dbSNP=http://www.ncbi.nlm.nih.gov/projects/SNP/snp_ref.cgi?rs=75025155
private String removeLinks(String s) {
  // TODO:......................
  return s
}

//------------------------------------------------------
// Remove the "lineNumBior=xxxx;" from the INFO column, including the semicolon after it if it occurs
// Ex:
//   lineNumBior=99
//   lineNumBior=99;A=1
//   A=1;lineNumBior=99
//   A=1;lineNumBior=
private String removeBiorLineNum(String infoCol) {
  int idx1 = infoCol.indexOf("lineNumBior=")
  int idx2 = infoCol.indexOf(";", idx1)
  
  if( idx1 == -1 )
    return infoCol

  if( idx2 == -1 ) // No semicolon found, so it must have been at the end of the line (remove end)
    idx2 = infoCol.length()

  // Remove the substring
  infoCol = infoCol.substring(0, idx1) + infoCol.substring(idx2)
  
  // Remove any semicolons at beginning
  while( infoCol.startsWith(";") ) 
    infoCol = infoCol.substring(1)

  // Remove any semicolons at end
  while( infoCol.endsWith(";") ) 
    infoCol = infoCol.substring(0, infoCol.length()-1)
    
  // Remove double-semicolons in middle of strings
  while( infoCol.contains(";;") )
    infoCol = infoCol.replace(";;", ";")
    
  // If there is nothing left, then return dot
  if( infoCol.trim().length() == 0 ) 
    infoCol = "."

  return infoCol
}

//------------------------------------------------------
// Determine if file is plain-text, gz, or bzip (just from extension), then return appropriate BufferedReader
private BufferedReader getBufferedReader(File file) {
  if( file.getName().endsWith(".bgz") ) {
    return new BufferedReader(new InputStreamReader(new BlockCompressedInputStream(file)));
  } else if( file.getName().endsWith(".gz") ) {
	return new BufferedReader(new InputStreamReader(new GZIPInputStream(new FileInputStream(file))))
  } else {
    return new BufferedReader(new InputStreamReader(new FileInputStream(file)))
  }
}


//------------------------------------------------------
private BlockCompressedOutputStream getBgzipWriter(File fileOut) {
  BlockCompressedOutputStream outStream = new BlockCompressedOutputStream(fileOut)
  return outStream
}


//=============================================================================================


private void runTestSuite() {
  testRemoveDotValues()
  testSortHeaders()
  testLinkedHashMapQueue()
  testConcat()
  testCol()
  testFirst7Cols()
  testMergeLine()
  testSameLine()
  testBiorLineNum()
  println("-------------------------------------")
  println("SUCCESS!  ALL TESTS PASSED!")
  println("-------------------------------------")
  System.exit(0)
}


private String testRemoveDotValues() {
  // Full
  assertEquals("AC=1;TU=wa01593;CAT=dog;yes=no", removeDotValues("AC=1;TU=wa01593;CAT=dog;yes=no"))
  // 1st two have dots
  assertEquals("CAT=dog;yes=no",                 removeDotValues("AC=.;TU=.;CAT=dog;yes=no"))
  // Last two have dots
  assertEquals("AC=1;TU=wa01593",                removeDotValues("AC=1;TU=wa01593;CAT=.;yes=."))
  // Mid two have dots
  assertEquals("AC=1;yes=no",                    removeDotValues("AC=1;TU=.;CAT=.;yes=no"))
  // First, mid, last have dots
  assertEquals("TU=wa01593",                     removeDotValues("AC=.;TU=wa01593;CAT=.;yes=."))
  // All have dots
  assertEquals(".",                              removeDotValues("AC=.;TU=.;CAT=.;yes=."))
}

private void testSortHeaders() {
  Set<String> headerSet = new HashSet<String>();
  headerSet.addAll(new ArrayList<String>(Arrays.asList(
	"##fileformat=VCFv4.1",
	"##fileDate=2017-10-02",
    "##source=bior_tjson_to_vcf",
	"##FILTER=<ID=PASS,Description=\"All filters passed\">",
	"##CombineVariants=\"analysis_type=CombineVariants input_file=[] read_buffer_size=null phone_home=NO_ET gatk_key=/projects/bsi/bictools/apps/alignment/GenomeAnalysisTK/1.6-5-g557da77/Hossain.Asif_mayo.edu.key read_filter=[] intervals=null excludeIntervals=null interval_set_rule=UNION interval_merging=ALL reference_sequence=/data2/bsi/reference/sequence/human/ncbi/37.1/allchr.fa nonDeterministicRandomSeed=false downsampling_type=BY_SAMPLE downsample_to_fraction=null downsample_to_coverage=1000 baq=OFF baqGapOpenPenalty=40.0 performanceLog=null useOriginalQualities=false BQSR=null quantize_quals=-1 defaultBaseQualities=-1 validation_strictness=SILENT unsafe=null num_threads=1 num_cpu_threads=null num_io_threads=null num_bam_file_handles=null read_group_black_list=null pedigree=[] pedigreeString=[] pedigreeValidationType=STRICT allow_intervals_with_unindexed_bam=false logging_level=INFO log_to_file=null help=false variant=[(RodBinding name=variant source=/data2/bsi/RandD/sampleData/Genome_GPS/sb/exome/110815_SN316_0162_AD07MMACXX/variants//s_tumor/s_tumor.variants.chr22.raw.vcf), (RodBinding name=variant2 source=/data2/bsi/RandD/sampleData/Genome_GPS/sb/exome/110815_SN316_0162_AD07MMACXX/variants//s_tumor/s_tumor.variants.chr21.raw.vcf)] out=org.broadinstitute.sting.gatk.io.stubs.VCFWriterStub NO_HEADER=org.broadinstitute.sting.gatk.io.stubs.VCFWriterStub sites_only=org.broadinstitute.sting.gatk.io.stubs.VCFWriterStub genotypemergeoption=PRIORITIZE filteredrecordsmergetype=KEEP_IF_ANY_UNFILTERED multipleallelesmergetype=BY_TYPE rod_priority_list=variant2,variant printComplexMerges=false filteredAreUncalled=false minimalVCF=false setKey=set assumeIdenticalSamples=false minimumN=1 suppressCommandLineHeader=false mergeInfoWithMaxAC=false filter_mismatching_base_and_quals=false\"",
	"##INFO=<ID=AC,Number=A,Type=Integer,Description=\"Allele count in genotypes, for each ALT allele, in the same order as listed\">",
	"##BIOR=<ID=\"ToTJson\",Operation=\"vcf_to_tjson\",DataType=\"JSON\",ShortUniqueName=\"ToTJson\">",
  )));
  headerSet.addAll(new ArrayList<String>(Arrays.asList(
	"##INFO=<ID=SB,Number=1,Type=Float,Description=\"Strand Bias\">",
	"##FILTER=<ID=PASS,Description=\"All filters passed\">",
	"##contig=<ID=chr20,length=63025520>",
	"##contig=<ID=chr10,length=135534747>",
	"##source=bior_tjson_to_vcf",
	"##BIOR=<ID=\"1000genomes_20130502_GRCh37_nodups\",Operation=\"same_variant\",DataType=\"JSON\",ShortUniqueName=\"1000genomes_20130502_GRCh37_nodups\",Source=\"1000_genomes\",Description=\"1000 Genomes Project goal is to find most genetic variants that have frequencies of at least 1% in the populations studied.\",Version=\"20130502\",Build=\"GRCh37\",Path=\"/data5/bsi/catalogs/v1/1000_genomes/20130502_GRCh37/variants_nodups.v1/ALL.wgs.sites.vcf.tsv.bgz\">",
	"##fileformat=VCFv4.1",
	"##fileDate=2017-10-02"
  )));

  List<String> sortedHeaderList = sortHeaders(headerSet);
  assertEquals(11, sortedHeaderList.size());
  int i=0
  assertEquals("##fileformat=VCFv4.1",  sortedHeaderList.get(i++))
  assertEquals("##fileDate=2017-10-02", sortedHeaderList.get(i++))
  assertEquals("##source=bior_tjson_to_vcf",  sortedHeaderList.get(i++))
  assertEquals("##contig=<ID=chr10,length=135534747>",  sortedHeaderList.get(i++))
  assertEquals("##contig=<ID=chr20,length=63025520>",   sortedHeaderList.get(i++))
  assertEquals("##INFO=<ID=AC,Number=A,Type=Integer,Description=\"Allele count in genotypes, for each ALT allele, in the same order as listed\">",  sortedHeaderList.get(i++))
  assertEquals("##INFO=<ID=SB,Number=1,Type=Float,Description=\"Strand Bias\">",  sortedHeaderList.get(i++))
  assertEquals("##FILTER=<ID=PASS,Description=\"All filters passed\">",  sortedHeaderList.get(i++))
  assertEquals("##BIOR=<ID=\"1000genomes_20130502_GRCh37_nodups\",Operation=\"same_variant\",DataType=\"JSON\",ShortUniqueName=\"1000genomes_20130502_GRCh37_nodups\",Source=\"1000_genomes\",Description=\"1000 Genomes Project goal is to find most genetic variants that have frequencies of at least 1% in the populations studied.\",Version=\"20130502\",Build=\"GRCh37\",Path=\"/data5/bsi/catalogs/v1/1000_genomes/20130502_GRCh37/variants_nodups.v1/ALL.wgs.sites.vcf.tsv.bgz\">",  sortedHeaderList.get(i++))
  assertEquals("##BIOR=<ID=\"ToTJson\",Operation=\"vcf_to_tjson\",DataType=\"JSON\",ShortUniqueName=\"ToTJson\">",  sortedHeaderList.get(i++))

}


private void testLinkedHashMapQueue() {
  Map<Integer,String> map = new LinkedHashMap<Integer, String>() {
    protected boolean removeEldestEntry(Map.Entry eldest) {
      final int MAX_ENTRIES = 5
      return size() > MAX_ENTRIES
    }
  }
  map.put(1, "A")
  map.put(2, "B")
  map.put(3, "C")
  map.put(4, "D")
  map.put(5, "E")
  map.put(6, "F")
  map.put(7, "G")
  assertEquals(5, map.size())
}

private void testConcat() {
  assertEquals("1", concat("1"))
  assertEquals("1\t2", concat("1", "2"))
  assertEquals("1\t2\t3\t4\t55555", concat("1", "2", "3", "4", "55555"))
}

private void testCol() {
  assertEquals("a", getCol("a", 1))
  assertEquals("",  getCol("a", 0))
  assertEquals("",  getCol("a", 2))
  assertEquals("A", getCol("A\tB", 1))
  assertEquals("B", getCol("A\tB", 2))
  assertEquals("",  getCol("A\tB", 3))
  assertEquals("A", getCol("A\tB\tC\tD", 1))
  assertEquals("B", getCol("A\tB\tC\tD", 2))
  assertEquals("C", getCol("A\tB\tC\tD", 3))
  assertEquals("D", getCol("A\tB\tC\tD", 4))
  assertEquals("",  getCol("A\tB\tC\tD", 5))
}

private void testFirst7Cols() {
  assertEquals("1", getFirst7Cols("1"))
  assertEquals("##12345678", getFirst7Cols("##12345678"))
  assertEquals("1\t2\t3\t4\t5\t6\t7", getFirst7Cols("1\t2\t3\t4\t5\t6\t7"))
  assertEquals("1\t2\t3\t4\t5\t6\t7", getFirst7Cols("1\t2\t3\t4\t5\t6\t7\t8"))
  assertEquals("1\t2\t3\t4\t5\t6\t7", getFirst7Cols("1\t2\t3\t4\t5\t6\t7\t8\t9\t10\t11\t12"))
}

// Should merge columns:  annot:1-7 + (orig:8+annot:8) + orig:9-x
private void testMergeLine() {
  // Test simple merge
  ORIGINAL = concat("a",  "b",  "c",  "d",  "e",  "f",  "g",  "x",   "y",  "z")
  ANNOTATED= concat("1",  "2",  "3",  "4",  "5",  "6",  "7",  "8",   "9",  "10")
  EXPECTED = concat("1",  "2",  "3",  "4",  "5",  "6",  "7",  "x;8", "y",  "z")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

  // Simple merge, where ORIGINAL INFO col is dot (should ignore it)
  // Both VCFs have just 8 columns (there should not be anymore than that in EXPECTED, and no odd tabs on end)
  ORIGINAL = concat("1", "100", "rs1", "A", "C", ".", ".", ".")
  ANNOTATED= concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3")
  EXPECTED = concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

  // Simple merge, where ORIGINAL INFO col and ANNOTATED INFO col are both dots (INFO should then just be a dot)
  ORIGINAL = concat("1", "100", "rs1", "A", "C", ".", ".", ".")
  ANNOTATED= concat("a", "b",   "c",   "d", "e", "f", "g", ".")
  EXPECTED = concat("a", "b",   "c",   "d", "e", "f", "g", ".")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

  // Should not use any columns beyond 8 from the annotated VCF
  ORIGINAL = concat("1", "100", "rs1", "A", "C", ".", ".", ".",            "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  ANNOTATED= concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3", "5",      ".|.")
  EXPECTED = concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3", "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

  // Verify that the lineNumBior=99 is removed  (at end)
  ORIGINAL = concat("1", "100", "rs1", "A", "C", ".", ".", ".",            "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  ANNOTATED= concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3;lineNumBior=99", "5",      ".|.")
  EXPECTED = concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3", "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

  // Verify that the lineNumBior=99 is removed  (in middle)
  ORIGINAL = concat("1", "100", "rs1", "A", "C", ".", ".", ".",            "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  ANNOTATED= concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;lineNumBior=99;AC=3", "5",      ".|.")
  EXPECTED = concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3", "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

  // Verify that the lineNumBior=99 is removed  (at start)
  ORIGINAL = concat("1", "100", "rs1", "A", "C", ".", ".", ".",            "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  ANNOTATED= concat("a", "b",   "c",   "d", "e", "f", "g", "lineNumBior=99;AF=0.24;AC=3", "5",      ".|.")
  EXPECTED = concat("a", "b",   "c",   "d", "e", "f", "g", "AF=0.24;AC=3", "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

  // Verify that the lineNumBior=99 is removed  (only key-value pair in line - should go to dot)
  ORIGINAL = concat("1", "100", "rs1", "A", "C", ".", ".", ".",              "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  ANNOTATED= concat("a", "b",   "c",   "d", "e", "f", "g", "lineNumBior=99", "5",      ".|.")
  EXPECTED = concat("a", "b",   "c",   "d", "e", "f", "g", ".",              "format", "sample1", "sample2", "sample3", "sample4", "sample5")
  assertEquals(EXPECTED, mergeLine(ANNOTATED, ORIGINAL))

}

private void testBiorLineNum() {
  assertEquals(99, getBiorLineNumFromInfo(concat("1", "2", "3", "4", "5", "6", "7", "lineNumBior=99",        "9", "10")))
  assertEquals(9,  getBiorLineNumFromInfo(concat("1", "2", "3", "4", "5", "6", "7", "lineNumBior=9;A=1",     "9", "10")))
  assertEquals(9,  getBiorLineNumFromInfo(concat("1", "2", "3", "4", "5", "6", "7", "A=1;lineNumBior=9",     "9", "10")))
  assertEquals(9,  getBiorLineNumFromInfo(concat("1", "2", "3", "4", "5", "6", "7", "A=1;lineNumBior=9;B=2", "9", "10")))
  assertEquals(9,  getBiorLineNumFromInfo(concat("1", "2", "3", "4", "5", "6", "7", "A=1;lineNumBior=9;Z",   "9", "10")))
}


private void testSameLine() {
  // Exact match
  assertTrue(isSameLine(
  		concat("1", "100", "rs1", "A", "C", "0.0", "vx=0", "AC=3"),
  		concat("1", "100", "rs1", "A", "C", "0.0", "vx=0", "AC=3") ))

  // Match, but with "chr" prefix, and differences in non-essential cols
  assertTrue(isSameLine(
  		concat("1",   "100", "rs1", "A", "C", "0.0",  "vx=0",  "AC=3"),
  		concat("chr1","100", "rs1", "A", "C", "0.00", "vx=0.0","AC=3.0") ))

  // Match, but with "chr" prefix, and ALTs subset
  assertTrue(isSameLine(
  		concat("1",   "100", "rs1", "A", "C",   "0.0",  "vx=0",  "AC=3"),
  		concat("chr1","100", "rs1", "A", "C,G", "0.00", "vx=0.0","AC=3.0") ))

  // NO Match, because ALT is not in the original ALTs set
  assertFalse(isSameLine(
  		concat("1",   "100", "rs1", "A", "A",   "0.0",  "vx=0",  "AC=3"),
  		concat("chr1","100", "rs1", "A", "C,G", "0.00", "vx=0.0","AC=3.0") ))
}

private String concat(String... s) {
  StringBuilder str = new StringBuilder()
  for(int i=0; i < s.length; i++) {
    if( i > 0 )
      str.append("\t")
    str.append(s[i])
  }
  return str.toString()
}
  