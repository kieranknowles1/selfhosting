#!/bin/bash

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


#===============================================================================
### Pause containers
#===============================================================================
echo "[INFO] Containers going PAUSED for backup"
for dir in services/*; do
  # We need the Borgmatic container, so don't pause it
  if [[ "$dir" == $BORG_SERVICE ]]; then
    continue
  fi

  echo "[INFO] Pausing $dir"
  docker-compose --file "$dir/docker-compose.yml" pause
done

echo "[INFO] Containers paused. Starting backup"

#===============================================================================
### Backup
#===============================================================================

# Start Borgmatic if it's not already running
docker-compose --file services/borgmatic/docker-compose.yml up --detach

# Run Borgmatic
docker-compose --file services/borgmatic/docker-compose.yml \
  exec borgmatic borgmatic --stats --verbosity 1

#===============================================================================
### Resume containers
#===============================================================================
echo "[INFO] Containers going UNPAUSED after backup"
for dir in services/*; do
  # It was never paused, so don't resume it
  if [[ "$dir" == $BORG_SERVICE ]]; then
    continue
  fi

  echo "[INFO] Unpausing $dir"
  docker-compose --file "$dir/docker-compose.yml" unpause
done
