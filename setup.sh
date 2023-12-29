#!/bin/bash
# Exit on error
set -e

# Setup script for self-hosted runner
# Installs dependencies and creates containers
# Requires root privileges

DEPS="docker docker-compose"

# Parse arguments
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

# Check for .env.user
if [ ! -f .env.user ]; then
  echo "ERROR: .env.user not found" >&2
  echo "Please create a .env.user file. See readme.md for more information" >&2
  exit
fi


if [ "$EUID" -ne 0 ]
  then echo "ERROR: Please run as root"
  exit
fi

if [ "$update" = false ]; then
  echo "Installing dependencies $DEPS"
  apt-get update
  apt-get install -y $DEPS
fi

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

echo "Restarting nginx"
docker-compose -f services/nginx/docker-compose.yml restart

start_dir=$(pwd)

if [ "$update" = false ]; then
  # Create a superuser for the paperless container
  cd services/paperlessngx
  docker-compose run --rm webserver createsuperuser
fi

cd $start_dir
