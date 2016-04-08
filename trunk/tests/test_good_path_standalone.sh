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

# For debug, uncomment this line:
PRINT_LEVEL="debug"

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
#   1 - file was not generated or is zero-length
#   2 - VCF exists, but does not have a valid format
validate_good_path() {
  # Set up input variables
  setup_inputs $TEST_DIR
  
  # Call bior_annotate.sh

  # Test whether VCF was created

  basic_file_validation all_tests.sh
  RETURN_CODE=$?

  print_results validate_good_path $RETURN_CODE

  return $?
  
}

## Assume all tests will pass
EXIT_CODE=0

## Begin test validations

validate_good_path
RETURN_CODE=$?
if [ ! "$RETURN_CODE" -eq "0" ]
then
  EXIT_CODE=1
fi

exit $EXIT_CODE
