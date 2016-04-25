#!/usr/bin/env bash

##########################################################################################################
##
##  This script will log the specified message (assuming that the print level is at or above the current
##  log level.
##
##  Usage notes:
##    1. By default, the print_level is "prod". This can be overridden using the following code:
##         source "/path/to/log.sh"
##         PRINT_LEVEL="debug"
##    2. By default, the assumed log level is "prod". This means that the message will always be printed
##    3. By design, all error and warning messages will always be printed. 
##    4. There are three levels of informational messages: debug, dev, and prod
##
##  Script Options:
##    $1 - Message to print
##    $2 - Message status level (warn, error, prod*, dev, debug)
##    $3 - Error code (should be unique within an application, eg. W3921)
##
##  Example usage:
##    log "Something interesting happened." "prod"
##    log "Something only interesting in debug mode happened" "debug"
##    log "Missing abc.txt" "error" "E1234"
##
#########################################################################################################

PRINT_LEVEL="prod"

log() {
  MESSAGE=$1
  LEVEL=$2
  ERROR_CODE=$3
  PREFIX="INFO"

  # Default level is production
  if [ -z $LEVEL ]
  then
    LEVEL="prod"
  fi

  if [ -z "$ERROR_CODE" ]
  then
    ERROR_CODE="NA"
  fi

  # Default to not printing the message
  PRINT_MESSAGE="false"

  case "$LEVEL" in
    "debug") 
      if [[ "$PRINT_LEVEL" == "debug" ]]
      then
        PRINT_MESSAGE="true"
      fi
      ;;
    "dev")
      if [[ "$PRINT_LEVEL" == "debug" || "$PRINT_LEVEL" == "dev" ]]
      then
        PRINT_MESSAGE="true"
      fi
      ;;
    "error")
      PRINT_MESSAGE="true"
      PREFIX="ERROR"
      ;;
    "prod")
      if [[ "$PRINT_LEVEL" == "debug" || "$PRINT_LEVEL" == "dev" || "$PRINT_LEVEL" == "prod" ]]
      then
        PRINT_MESSAGE="true"
      fi
      ;;
    "warn")
      PRINT_MESSAGE="true"
      PREFIX="WARNING"
      ;;
    *) PRINT_MESSAGE="false" ;;
  esac
  
  if [ "$PRINT_MESSAGE" == "true" ]
  then
    echo -e "$(date +%Y-%m-%d'T'%H:%M:%S%z) ${PREFIX} ${0-NA} ${SGE_TASK_ID-NA} ${ERROR_CODE-NA} ${MESSAGE}"
  fi
}
