PRINT_LEVEL="prod"

log() {
  MESSAGE=$1
  LEVEL=$2

  # Default level is production
  if [ -z $LEVEL ]
  then
    LEVEL="prod"
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
    "prod")
      if [[ "$PRINT_LEVEL" == "debug" || "$PRINT_LEVEL" == "dev" || "$PRINT_LEVEL" == "prod" ]]
      then
        PRINT_MESSAGE="true"
      fi
      ;;
    *) PRINT_MESSAGE="false" ;;
  esac
  
  if [ "$PRINT_MESSAGE" == "true" ]
  then
    echo "$MESSAGE"
  fi
}
