#!/bin/bash

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
source .env.user

docker-compose -f services/docker-compose.yml up -d --remove-orphans
