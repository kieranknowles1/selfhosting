#!/bin/bash

# Backup script for self-hosted runner
# Pauses containers, runs Borgmatic, and resumes containers
# WARN: If a backup fails, containers will not be resumed. A server reboot is recommended in this case

# Exit on error
set -e

# Load environment variables
source .env
source .env.user


#===============================================================================
### Pause containers
#===============================================================================
echo "[INFO] Containers going PAUSED for backup"
for dir in services/*; do
  echo "[INFO] Pausing $dir"
  docker-compose --file "$dir/docker-compose.yml" pause
done


#===============================================================================
### Backup
#===============================================================================
# Resume Borgmatic as we need it for the backup
docker-compose --file services/borgmatic/docker-compose.yml unpause

# Run Borgmatic
docker-compose --file services/borgmatic/docker-compose.yml \
  exec borgmatic borgmatic --stats --verbosity 1

#===============================================================================
### Resume containers
#===============================================================================
echo "[INFO] Containers going UNPAUSED after backup"
for dir in services/*; do
  echo "[INFO] Unpausing $dir"
  docker-compose --file "$dir/docker-compose.yml" unpause
done
