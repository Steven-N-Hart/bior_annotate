#!/bin/bash
# 
# File: common_functions.sh
# Description:
#   Contains functions used by all scripts

# Default is that debug mode is disabled. This flag can be overridden by files that source this file.
DEBUG="FALSE"

### Obtain functions defined in other files:
source "$BIOR_ANNOTATE/tests/utils/file_validation.sh"
source "$BIOR_ANNOTATE/tests/utils/log.sh"

### Functions defined in this file (alphabetic order):
# call_bior_annotate
# cleanup_test
# print_results
# setup_inputs

# Function: call_bior_annotate
# Description:
#   Calls bior_annotate.sh using a specified test directory
#
# Argument (empty strings will use defaults): 
#   $1 - destination directory
#
# Environment variables used=default value:
#   BIOR_CATALOGS="$BIOR_ANNOTATE/config/catalog_file"
#   BIOR_DRILLS="$BIOR_ANNOTATE/config/drill_file"
#   INPUT_VCF="test.vcf"
#   MEMORY_INFO="$BIOR_ANNOTATE/config/memory_info.txt"
#   OUTPUT_VCF="test_output.vcf"
#   QUEUE="1-day"
#   TOOL_INFO="$BIOR_ANNOTATE/config/tool_info.txt"
#
# Usage: 
#   Disable queue
#   QUEUE=NA
#   call_bior_annotate $DESTINATION_DIR
# 
# Returns:
#   0 - success
#   1 - failed
call_bior_annotate() {
  DESTINATION_DIR=$1

  basic_dir_validation "$DESTINATION_DIR" 
  RC=$?

  if [[ "$RC" != "0" ]]
  then
    log "Directory validation of DESTINATION_DIR=$DESTINATION_DIR failed with RC - $RC"
    return 1
  fi

  # Set up default values used if nothing else overrides them.
  if [ -z "$BIOR_CATALOGS" ]
  then
    BIOR_CATALOGS="$BIOR_ANNOTATE/config/catalog_file"
  fi

  if [ -z "$BIOR_DRILLS" ]
  then
    BIOR_DRILLS="$BIOR_ANNOTATE/config/drill_file"
  fi

  if [ -z "$INPUT_VCF" ]
  then
    INPUT_VCF="test.vcf"
  fi

  if [ -z "$MEMORY_INFO" ]
  then
    MEMORY_INFO="$BIOR_ANNOTATE/config/memory_info.txt"
  fi

  if [ -z "$OUTPUT_VCF" ]
  then
    OUTPUT_VCF="test_out"
  fi

  if [ -z "$QUEUE" ] 
  then
    QUEUE="1-day"  
  fi

  if [ -z "$TOOL_INFO" ]
  then
    TOOL_INFO="$BIOR_ANNOTATE/config/tool_info.txt"
  fi

  # Ensure that all values are valid
  basic_file_validation "$BIOR_CATALOGS"
  if [[ "$RC" != "0" ]]
  then
    log "BIOR_CATALOGS=$BIOR_CATALOGS does not point to a valid file - RC: $RC"
    exit 1
  fi

  basic_file_validation "$BIOR_DRILLS"
  if [[ "$RC" != "0" ]]
  then
    log "BIOR_DRILLS=$BIOR_DRILLS does not point to a valid file - RC: $RC"
    exit 1
  fi

  basic_file_validation "$INPUT_VCF"
  if [[ "$RC" != "0" ]]
  then
    log "INPUT_VCF=$INPUT_VCF does not point to a valid file - RC: $RC"
    exit 1
  fi

  basic_file_validation "$MEMORY_INFO"
  if [[ "$RC" != "0" ]]
  then
    log "MEMORY_INFO=$MEMORY_INFO does not point to a valid file - RC: $RC"
    exit 1
  fi

  basic_file_validation "$TOOL_INFO"
  if [[ "$RC" != "0" ]]
  then    log "TOOL_INFO=$TOOL_INFO does not point to a valid file - RC: $RC"
    exit 1
  fi

  CMD="$BIOR_ANNOTATE/bior_annotate.sh -v $DESTINATION_DIR/$INPUT_VCF -c $BIOR_CATALOGS -d $BIOR_DRILLS -O $DESTINATION_DIR -o $OUTPUT_VCF -x $DESTINATION_DIR -T $TOOL_INFO -M $MEMORY_INFO -l -j AUTO_TEST.bior_annotate. -Q $QUEUE"

  log "Calling: $CMD" "debug"
  eval $CMD
  

}

# Function: 
# Description:
#   Deletes all files in destination directory
#
# Argument (empty strings will use defaults): 
#   $1 - destination directory
#
# Usage: 
#   cleanup_test $DESTINATION_DIR
# 
# Returns:
#   0 - success
#   1 - failed
cleanup_test() {
  DESTINATION_DIR=$1

  basic_dir_validation "$DESTINATION_DIR" 
  RC=$?

  if [[ "$RC" != "0" ]]
  then
    log "Directory validation of DESTINATION_DIR=$DESTINATION_DIR failed with RC - $RC"
    return 1
  fi

  # If we reach this point, directory validation passed. It should be safe to delete from here.
  if [[ "$DEBUG" == "FALSE" ]]
  then 
    rm -v "$DESTINATION_DIR/.bior.*/*"
    rmdir -v "$DESTINATION_DIR/.bior.*"
    rmdir -v "$DESTINATION_DIR/"
  else
    log "Not deleting files in $DESTINATION_DIR because DEBUG is enabled." 
  fi

  # Assume the deletes worked.
  return 0
}


# Function: print_results
# Description:
#   Prints the results of a test based on its return code
#
# Arguments: 
#   $1 - Test name (should match name of function to ease searching)
#   $2 - Return code from test
#
# Usage: 
#   print_results <test_name> <return_code>
# 
# Returns:
#   0 - success
#   1 - test reported failure
print_results() {
  TESTNAME=$1
  RETURN_CODE=$2

  # Assume success
  EXIT_CODE=0

  if [ "$RETURN_CODE" -eq "0" ]
  then
    RESULT="PASSED"
  else
    RESULT="FAILED with rc $RETURN_CODE"
    EXIT_CODE=1
  fi

  log "TEST: $TESTNAME $RESULT"

  return $EXIT_CODE
}

# Function: setup_inputs
# Description:
#   Copies input files to temporary test directory
#
# Arguments (all are optional, empty strings will use defaults): 
#   $1 - destination directory
#   $2 - Test VCF (default: sample_config/test.vcf)
#   $3 - tool_info (default: sample_config/tool_info.minimal.txt)
#   $4 - catalog_file (default: sample_config/catalog_file)
#   $5 - drill_file (default: sample_config/drill_file)
#   $6 - memory_info (default: sample_config/memory_info.txt)
#
# Usage: 
#   setup_inputs
#   setup_inputs sample.vcf
#   setup_inputs "" new_tool_info.txt
# 
# Returns:
#   0 - success
#   1 - failed
setup_inputs() {
  DESTINATION_DIR=$1
  TEST_VCF=$2
  TOOL_INFO=$3
  CATALOG_FILE=$4
  DRILL_FILE=$5
  MEMORY_INFO=$6

  basic_dir_validation $DESTINATION_DIR

  if [ ! $? -eq 0 ]
  then
    log "Destination directory not specified or does not exist"
    exit 1
  fi 

  if [ -z "$TEST_VCF" ]
  then
    TEST_VCF="$BIOR_ANNOTATE/tests/sample_config/test.vcf"
  fi
  
  if [ -z "$TOOL_INFO" ]
  then
    TOOL_INFO="$BIOR_ANNOTATE/tests/sample_config/tool_info.minimal.txt"
  fi

  if [ -z "$CATALOG_FILE" ]
  then
    CATALOG_FILE="$BIOR_ANNOTATE/tests/sample_config/catalog_file"
  fi

  if [ -z "$DRILL_FILE" ]
  then
    DRILL_FILE="$BIOR_ANNOTATE/tests/sample_config/drill_file"
  fi

  if [ -z "$MEMORY_INFO" ]
  then
    MEMORY_INFO="$BIOR_ANNOTATE/tests/sample_config/memory_info.txt"
  fi

  for FILE in "$TEST_VCF" "$TOOL_INFO" "$CATALOG_FILE" "$DRILL_FILE" "$MEMORY_INFO"
  do
    basic_file_validation "$FILE"  

    RETURN_CODE=$?

    log "$FILE - RC=$RETURN_CODE" "debug"
    if [ ! "$RETURN_CODE" -eq "0" ]
    then
      log "Copying files failed. Aborting."
      exit 1
    fi

    cp $FILE $DESTINATION_DIR/
  done


}