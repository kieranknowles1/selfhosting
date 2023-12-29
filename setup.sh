#!/bin/bash
# Exit on error
set -e

# Setup script for self-hosted runner
# Installs dependencies and creates containers
# Requires root privileges

DEPS="docker docker-compose"

# Parse arguments
show_help=false
update_only=false
while getopts ":h-:" opt; do
  case "$opt" in
    h)
      show_help=true
      ;;
    -)
      case "${OPTARG}" in
        update-only)
          update_only=true
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
  echo "  --update-only: Only update containers, do not perform additional setup"

  exit
fi


if [ "$EUID" -ne 0 ]
  then echo "ERROR: Please run as root"
  exit
fi

echo "Installing dependencies $DEPS"
apt-get update
apt-get install -y $DEPS

echo "Creating containers"
source .env
source .env.user

# TODO: Want a backup system for containers content

for dir in services/*; do
  echo "Creating container for $dir"
  docker-compose -f $dir/docker-compose.yml up --detach --remove-orphans
done

start_dir=$(pwd)

if [ "$update_only" = false ]; then
  # Create a superuser for the paperless container
  cd services/paperlessngx
  docker-compose run --rm webserver createsuperuser
fi

cd $start_dir
