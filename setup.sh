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
expand_cert=false
update=false
while getopts ":h-:" opt; do
  case "$opt" in
    h)
      show_help=true
      ;;
    -)
      case "${OPTARG}" in
        certbot)
          expand_cert=true
          ;;
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
  echo "  --certbot: Update/expand SSL certificate"
  echo "  --update: Update containers without reinstalling everything"

  exit
fi

#===============================================================================
### Functions
#===============================================================================
reload_nginx() {
  echo "Reloading nginx configuration"
  docker-compose -f services/nginx/docker-compose.yml exec nginx nginx -s reload
}

# Get the subdomain from the $SUBDOMAINS array
# $1: The array entry
get_subdomain() {
  echo $1 | cut -d' ' -f1
}

# Generate the nginx configuration for a subdomain
# $1: Subdomain
# $2: Port
generate_nginx_config() {
  local subdomain=$1
  local port=$2

  echo "
    # ${subdomain}, ${port}
    server {
        include /etc/nginx/includes/global.conf;
        server_name ${subdomain}.${DOMAIN_NAME};

        location / {
            proxy_pass http://${LOCAL_IP}:${port}/;
            proxy_set_header Host §host;
            proxy_set_header X-Real-IP §remote_addr;
            proxy_set_header X-Forwarded-For §proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto §scheme;
            proxy_set_header Upgrade §http_upgrade;
            proxy_set_header Connection \"Upgrade\";
        }
    }
  "
}

# Generate the gatus configuration for a service
# $1: Subdomain
# $2: Name
generate_gatus_config() {
  local subdomain=$1
  local name=$2

  # NOTE: Indentation is important here since this is a YAML file
  echo "
  - name: ${name}
    group: Services
    url: https://${subdomain}.${DOMAIN_NAME}
    interval: 5m
    conditions:
      - \"[STATUS] == 200\"
      - \"[RESPONSE_TIME] < ${HEALTH_TIMEOUT}\"
  "
}

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

  echo "Giving current user access to docker"
  sudo usermod -aG docker $USER
fi

#===============================================================================
### Configuration
#===============================================================================
source .env
source .env.user

export NGINX_CONFIG=""
export GATUS_CONFIG=""
for entry in "${SUBDOMAINS[@]}"; do
  IFS=';' read -ra split <<< "$entry"
  subdomain=$(get_subdomain ${split[0]})
  port=${split[1]}
  name=${split[2]}

  NGINX_CONFIG+=$(generate_nginx_config "$subdomain" "$port")
  GATUS_CONFIG+=$(generate_gatus_config "$subdomain" "$name")
done

echo "Replacing variables in .template files"
for file in $(find services -name "*.template"); do
  echo "Replacing variables in $file"
  envsubst < $file | sed 's/§/$/g' > ${file%.template}
done

#===============================================================================
### Container creation
#===============================================================================
echo "Creating containers"

for dir in $(ls services); do
  echo "Creating or updating containers for $dir"
  docker-compose -f "services/$dir/docker-compose.yml" up --detach --remove-orphans
done

#===============================================================================
### Configuration
#===============================================================================

# not updating or user has requested certbot update
if [ "$expand_cert" = true ] || [ "$update" = false ]; then
  echo "Issuing SSL certificate"

  # Reload nginx in case the config has changed
  # Need to reload again after issuing certificate to ensure the latest cert is used
  reload_nginx

  # Need to issue a certificate that covers all subdomains
  docker-compose -f services/nginx/docker-compose.yml run --rm certbot \
    certonly --webroot --webroot-path=/var/www/certbot \
    --email ${OWNER_EMAIL} \
    -d ${DOMAIN_NAME} \
    $(for subdomain in "${SUBDOMAINS[@]}"; do echo "-d $(get_subdomain $subdomain).${DOMAIN_NAME}"; done)
fi

if [ "$update" = false ]; then

  (
    echo "Creating superuser for paperless container"
    cd services/paperlessngx
    docker-compose run --rm webserver createsuperuser
  )

  echo "Configuring borgmatic"
  docker exec borgmatic borgmatic init --encryption repokey
  docker exec borgmatic borg key export /mnt/repo > .borg-key.local
  docker exec borgmatic borg key export ${BORGBASE_URL} > .borg-key.borgbase
fi

#===============================================================================
### Maintenance
#===============================================================================

reload_nginx

echo "========================================================================="
echo "Setup complete"
echo "========================================================================="
echo "Please back up the following files:"
echo "  - .env.user"
echo "  - .borg-key.local"
echo "  - .borg-key.borgbase"
echo "See readme.md for remaining setup steps"
