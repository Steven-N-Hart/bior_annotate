//--------------------------------------------------------------------------------------------------
// Cut out the sample columns to reduce the memory and processing overload for bior_annotate.sh
// when running with VCFs with lot of sample columns (hundreds to thousands).  This must be used
// with the merge.groovy script to combine the sample and header info from the original VCF after
// annotation is finished.
// 
// This should be run after the vcf-split command is called which splits lines with multiple alts
// 
// Given a VCF input from STDIN, this:
//   - cuts out the FORMAT and all sample columns, truncating to 8 columns.
//   - replaces the INFO column with a dot.
//   - removes any headers that may cause problems (like ##FORMAT and ##SAMPLE)
//   - adds a "biorLineNum" key to the INFO column to help merge after annotation
//   - outputs to STDOUT
//--------------------------------------------------------------------------------------------------

import java.util.zip.GZIPOutputStream;


if( args.length != 1 ) {
  usage()
  System.exit(1)
}

// Process the input - removing the sample columns, etc
File lineNumToSamplesMapFileOut = new File(args[0])
removeSampleColumns(lineNumToSamplesMapFileOut)


//----------------------------------------------------------------------------------------

//------------------------------------------------------
private void usage() {
  println("groovy cutSamples.groovy  <lineNumToSamplesMapFileOutput>")
  println("  lineNumToSamplesMapFileOutput  is the path to a file that will be created for storing the line number to FORMAT and SAMPLE columns mappings.")
}

//------------------------------------------------------
private void removeSampleColumns(File lineNumToSamplesMapFileOut) {
  BufferedReader vcfReader = new BufferedReader(new InputStreamReader(System.in));
  BufferedWriter vcfWriter = new BufferedWriter(new OutputStreamWriter(System.out));
  BufferedWriter samplesWriter = new BufferedWriter( new OutputStreamWriter(
    new GZIPOutputStream(new FileOutputStream(lineNumToSamplesMapFileOut))));


  String line = null;
  long lineNum = 1;
  while( (line = vcfReader.readLine()) != null ) {
    lineNum += writeLine(vcfWriter, samplesWriter, line, lineNum)
  }
  
  vcfWriter.flush()
  samplesWriter.flush()
  
  vcfReader.close();
  vcfWriter.close();
  samplesWriter.close();
}

//------------------------------------------------------
// Write line to output and return the number of data lines written (usually 0 for headers or 1 for actual data lines)
// Also, write all ## headers, and truncated lines (# header and data lines) to separate file for later merge
private int writeLine(BufferedWriter vcfWriter, BufferedWriter samplesWriter, String line, long lineNum) {
    int numDataLinesWritten = 0;

	String shortLine = ""
	String samplesLine = ""

    // Don't output ##SAMPLE and ##FORMAT lines
    if( line.startsWith("##SAMPLE") || line.startsWith("##FORMAT") ) {
      // Don't output these lines to the cut VCF
      shortLine = ""
      // Output these to the samples file
      samplesLine = line + "\n"
    } else if( line.startsWith("##") ) {
      shortLine   = line + "\n"
      samplesLine = line + "\n"
    } else if( line.startsWith("#") ) {
      // Then cut the column header line to the first 7 cols and add "INFO" back on
      shortLine = getFirst7Cols(line) + "\t" + "INFO" + "\n";
      // Samples line will have the DataLineNum out front, followed by the INFO, FORMAT, SAMPLE columns at end
      samplesLine = "#DataLineNum" + "\t" + cutOffFirst7Cols(line) + "\n"
    } else {
      shortLine = getFirst7Cols(line) + "\t" + "lineNumBior=" + lineNum + "\n";
      // Samples line will have the DataLineNum out front, followed by the INFO, FORMAT, SAMPLE columns at end
      samplesLine = lineNum + "\t" + cutOffFirst7Cols(line) + "\n"
      numDataLinesWritten = 1
    }

	if( shortLine.length() > 0 )    
	    vcfWriter.write(shortLine)
    samplesWriter.write(samplesLine)
    
    return numDataLinesWritten
}

//------------------------------------------------------
private String cutOffFirst7Cols(String s) {
  return s.replace(getFirstXCols(s,7), "").trim()
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
