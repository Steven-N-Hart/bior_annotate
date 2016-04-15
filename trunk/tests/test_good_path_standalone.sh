#!/bin/bash

usage()
{
cat << EOF
#################################################################################################################
##      Script: test_good_path_standalone.sh
##
##	Options:
##	-d <tool_install_directory>    - (REQUIRED) /dir/to/bior_annotate/
##	-h                             - Display this usage/help text (No arg)
##      -t <test_directory>            - /dir/to/tempdir/ (assumes current working directory)
##
#################################################################################################################
EOF
}

### Arguments parsing and prerequisite checking
# Defaults:
TEST_DIR="."

while getopts "d:ht:" OPTION; do
  case $OPTION in
	d) BIOR_ANNOTATE=$OPTARG;;
	h) usage
	   exit ;;
        t) TEST_DIR=$OPTARG;;
        *) echo "Invalid option: -$OPTARG. See output file for usage." >&2
           usage
           exit ;;
  esac
done

if [ -z "$BIOR_ANNOTATE" ]
then
  echo "ERROR: Path to bior_annotate project is required."
  exit 1 
fi

TEST_DIR="$TEST_DIR/tmp.$RANDOM/"
mkdir $TEST_DIR

### Source utility files that contain shared functions
source "$BIOR_ANNOTATE/tests/utils/common_functions.sh"

# For print level, specify debug, dev, or prod (prod is recommended for automated tests)
PRINT_LEVEL="debug"

# For debug, uncomment this line:
DEBUG="TRUE"

### Begin test functions

# Function: validate_good_path
# Description:
#   Performs the following basic good path validation:
#   1. Run bior_annotate on test VCF
#   2. Checks to ensure that result VCF exists at output location.
#
# Arguments: 
#   $1 - Path to test VCF
#   $2 - Path to output directory
#
# Usage: 
#   validate_good_path $testvcf $outputdir
# 
# Returns:
#   0 - success, all checks passed
#   1 - VCF did not pass validation
#   2 - Tabix index file did not pass validation
validate_good_path() {
  # Assume success
  TEST_RESULT="0"

  # Call bior_annotate.sh
  QUEUE="NA"
  call_bior_annotate $TEST_DIR

  # Test whether expected files were created
  file_list_validation "$TEST_DIR/test_out.vcf.gz $TEST_DIR/test_out.vcf.gz.tbi"
  RETURN_CODE=$?

  return $RETURN_CODE
  
}

### Starting values
# Assume all tests will pass
EXIT_CODE=0

# Start with test 1
TEST_NUMBER=1

# Tests executed:
TESTS="validate_good_path validate_good_path_table"

### Run tests in list
for TEST in $TESTS
do
  ## Begin test validations
  setup_inputs $TEST_DIR

  $TEST

  RETURN_CODE=$?
  print_results "$TEST_NUMBER" "$TEST" "$RETURN_CODE" 

  # if successful, no need to keep test directory
  if [[ "$RETURN_CODE" == "0" ]]
  then
    cleanup_test $TEST_DIR
  else
    EXIT_CODE=1
  fi

  let TEST_NUMBER=$TEST_NUMBER+1
done

print_summary

exit $EXIT_CODE
