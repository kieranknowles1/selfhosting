#!/bin/bash
# Exit on error
set -e

# Setup script for self-hosted runner
# Installs dependencies and creates containers
# Requires root privileges

DEPS="docker docker-compose"

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
  docker-compose -f $dir/docker-compose.yml up --detach --remove-orphans --force-recreate
done

start_dir=$(pwd)

# Create a superuser for the paperless container
cd services/paperlessngx
docker-compose run --rm webserver createsuperuser

cd $start_dir
