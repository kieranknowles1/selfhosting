#!/bin/bash

log() {
  echo "[INFO] $1"
  echo "[INFO] $1" >> backup.log
}

# Run from cron, so need to CD here from home directory
cd "$(dirname "$0")"

# Backup script for self-hosted runner
# Pauses containers, runs Borgmatic, and resumes containers
# WARN: If a backup fails, containers will not be resumed. A server reboot is recommended in this case

# Exit on error
set -e

BORG_SERVICE="services/borgmatic"

# Load environment variables
source .env
source .env.user

log "========================="
log " --- Starting backup --- "
log "Backup started at $(date)"
log "========================="

#===============================================================================
### Pause containers
#===============================================================================
log "Containers going PAUSED for backup"
for dir in ${BACKUP_PAUSE_SERVICES[@]}; do
  log "Pausing $dir"
  docker-compose --file "services/$dir/docker-compose.yml" pause | tee -a backup.log
done

log "Containers paused. Starting backup"

#===============================================================================
### Backup
#===============================================================================

log "Starting Borgmatic"
docker-compose --file services/borgmatic/docker-compose.yml up --detach

log "Running Borgmatic"
docker-compose --file services/borgmatic/docker-compose.yml \
  exec -T borgmatic borgmatic --stats --verbosity 1 | tee -a backup.log

#===============================================================================
### Resume containers
#===============================================================================
log "Containers going UNPAUSED after backup"
for dir in ${BACKUP_PAUSE_SERVICES[@]}; do
  echo "[INFO] Unpausing $dir"
  docker-compose --file "services/$dir/docker-compose.yml" unpause | tee -a backup.log
done

log "Backup complete"
