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

# Disallow running as root
if [ "$EUID" -eq 0 ]; then
  echo "ERROR: This script should not be run as root" >&2
  exit 1
fi

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
  echo "Configuring certbot"
  docker-compose -f services/nginx/docker-compose.yml run --rm certbot \
    certonly --webroot --webroot-path=/var/www/certbot \
    --email ${OWNER_EMAIL} -d ${DOMAIN_NAME}

  (
    echo "Creating superuser for paperless container"
    cd services/paperlessngx
    docker-compose run --rm webserver createsuperuser
  )

  echo "Configuring borgmatic"
  docker exec borgmatic borg init /mnt/repo --encryption repokey
  docker exec borgmatic borg key export /mnt/repo > .borg-key
fi

#===============================================================================
### Maintenance
#===============================================================================

echo "Restarting nginx"
docker-compose -f services/nginx/docker-compose.yml restart

echo "========================================================================="
echo "Setup complete"
echo "========================================================================="
echo "Please back up the following files:"
echo "  - .env.user"
echo "  - .borg-key"
echo "See readme.md for remaining setup steps"
