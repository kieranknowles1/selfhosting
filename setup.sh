#!/bin/bash
# Exit on error
set -e

# Setup script for self-hosted runner
# Installs dependencies and creates containers

DEPS="docker docker-compose"

COMPOSE_PROJECT_NAME="self-hosted"

#===============================================================================
### Arguments
#===============================================================================
show_help=false
update=false
while getopts ":h-:" opt; do
  case "$opt" in
    h)
      show_help=true
      ;;
    -)
      case "${OPTARG}" in
        update)
          update=true
          ;;
        *)
          echo "ERROR: Invalid option: --${OPTARG}" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "ERROR: Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

if [ "$show_help" = true ]; then
  echo "Usage: $0"
  echo "  -h, --help: Show this help message"
  echo "  --update: Update containers without reinstalling everything"

  exit
fi

#===============================================================================
### Readiness checks
#===============================================================================

if [ ! -f .env.user ]; then
  echo "ERROR: .env.user not found" >&2
  echo "Please create a .env.user file. See readme.md for more information" >&2
  exit 1
fi

if [ "$update" = false ]; then
  echo "Installing dependencies $DEPS"
  echo "This requires root privileges"
  sudo apt-get update
  sudo apt-get install -y $DEPS
fi

#===============================================================================
### Container creation
#===============================================================================
source .env
source .env.user

echo "Replacing variables in .template files"
for file in $(find services -name "*.template"); do
  echo "Replacing variables in $file"
  envsubst < $file | sed 's/§/$/g' > ${file%.template}
done

echo "Creating containers"

# TODO: Want a backup system for containers content

for dir in services/*; do
  echo "Creating container for $dir"
  docker-compose -f $dir/docker-compose.yml up --detach --remove-orphans
done

#===============================================================================
### Configuration
#===============================================================================

if [ "$update" = false ]; then
  (
    # Create a superuser for the paperless container
    cd services/paperlessngx
    docker-compose run --rm webserver createsuperuser
  )
fi

#===============================================================================
### Maintenance
#===============================================================================

echo "Restarting nginx"
docker-compose -f services/nginx/docker-compose.yml restart
