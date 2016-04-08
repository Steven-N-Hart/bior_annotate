#!/bin/bash

# Function: basic_file_validation
# Description:
#   Performs the following basic file validation:
#   1. File exists at the specified location 
#   2. File is non-empty
#
# Arguments: 
#   $1 - full path file to validate
#
# Usage: 
#   basic_file_validation $file
# 
# Returns:
#   0 - success, all checks passed
#   1 - filename is an empty string
#   2 - file does not exist
#   3 - file exists, but is empty
basic_file_validation() {
  filename=$1

  if [ "$filename" == "" ] 
  then
    return 1
  elif [ ! -e "$filename" ] 
  then
    return 2
  elif [ -z "$filename" ]
  then
    return 3
  fi

  return 0
}

# Function: basic_dir_validation
# Description:
#   Performs the following basic directory validation:
#   1. File exists at the specified location 
#   2. File is a directory
#
# Arguments: 
#   $1 - full path of directory to validate
#
# Usage: 
#   basic_dir_validation $dir
# 
# Returns:
#   0 - success, all checks passed
#   1 - filename is an empty string
#   2 - file does not exist
#   3 - file exists, but is not a directory
basic_dir_validation() {
  dirname=$1

  if [ "$dirname" == "" ]
  then
    return 1
  elif [ ! -e "$dirname" ]
  then
    return 2
  elif [ ! -d "$dirname" ]
  then
    return 3
  fi

  return 0
}

