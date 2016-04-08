#!/bin/bash
# 
# File: common_functions.sh
# Description:
#   Contains functions used by all scripts

### Obtain functions defined in other files:
source "$BIOR_ANNOTATE/tests/utils/file_validation.sh"
source "$BIOR_ANNOTATE/tests/utils/log.sh"

### Functions defined in this file:
# print_results
# setup_inputs
# cleanup_test

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

  # Assume success
  EXIT_CODE=0

  return $EXIT_CODE

}
