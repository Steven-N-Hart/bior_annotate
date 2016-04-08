source log.sh

log "hello_world"

log "hello_dev" "dev"

log "hello_debug" "debug"

for PRINT_LEVEL in "prod" "dev" "debug" "other"
do
  export $PRINT_LEVEL

  log "hello_world $PRINT_LEVEL"

  log "hello_dev $PRINT_LEVEL" "dev"

  log "hello_debug $PRINT_LEVEL" "debug"
done
