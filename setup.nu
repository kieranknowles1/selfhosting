#!/usr/bin/env nu

use logging.nu *
use services.nu get_services

# Setup script for self-hosted runner
# Installs dependencies and creates containers
def main [
    --certbot   # Update/expand SSL certificate
    --update    # Update containers without reinstalling everything"
] {
    if (is-admin) {
        log error "This script should not be run as root"
        exit 1
    }

    if ($update == false) {
        install_deps
    }

    let local_address = $"(hostname).local"
    let domain_name = "example.com"

    let environment = {
        ...(open environment.yml)
        ...(open userenv.yml)
    }

    let services = get_services $environment

    let nginx_config = $services | each {|s| generate_nginx_config $s $local_address $domain_name } | str join

    let templates = (ls **/*.template) | where (|$it| not ($it | is-empty)) | get name
    # FIXME: Piping to null suppresses logging, using a discard variable as a workaround
    let _ = $templates | each {|template|
        log info $"Replacing variables in ($template)"
        let output_file = $template | str replace ".template" ""
        open $template --raw | replace_vars $environment | save $output_file --force --raw
    }
}

# Install dependencies and give the current user the needed permissions
def install_deps [] {
    log info "Installing dependencies"
    log info "This requires root privileges"
    sudo apt-get update
    sudo apt-get install -y docker docker-compose

    log info "Giving current user access to docker"
    sudo usermod -aG docker $env.USER
}

# Generate the nginx configuration for a service
def generate_nginx_config [
    service: record<domain: string, port: int>
    local_address: string
    domain_name: string
]: nothing -> string {$"
    # ($service.domain), ($service.port)
    server {
        include /etc/nginx/includes/global.conf;
        server_name ($service.domain).($domain_name);

        location / {
            proxy_pass http://($local_address):($service.port)/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection \"Upgrade\";
        }
    }
"}

def replace_vars [
    vars: record
] string -> string {
    each { |raw|
        with-env $vars {
            # TODO: Using envsubst here isn't ideal, can't detect missing variables
            $raw | envsubst
        }
    }
}

# TODO: Rewrite for nushell

# COMPOSE_PROJECT_NAME="self-hosted"

# #===============================================================================
# ### Functions
# #===============================================================================
# reload_nginx() {
#   echo "Reloading nginx configuration"
#   docker-compose -f services/nginx/docker-compose.yml exec nginx nginx -s reload
# }

# # Get the subdomain from the $SUBDOMAINS array
# # $1: The array entry
# get_subdomain() {
#   IFS=";" read -ra split <<< $1
#   echo ${split[0]}
# }

# # Generate the gatus configuration for a service
# # $1: Subdomain
# # $2: Name
# # $3: Health endpoint (optional)
# generate_gatus_config() {
#   local subdomain=$1
#   local name=$2
#   local health_endpoint=${3:-"/"}

#   # NOTE: Indentation is important here since this is a YAML file
#   echo "
#   - name: ${name}
#     group: Services
#     url: https://${subdomain}.${DOMAIN_NAME}${health_endpoint}
#     interval: 5m
#     conditions:
#       - \"[STATUS] == 200\"
#       - \"[RESPONSE_TIME] < ${HEALTH_TIMEOUT}\"
#   "
# }

# #===============================================================================
# ### Readiness checks
# #===============================================================================

# if [ ! -f .env.user ]; then
#   echo "ERROR: .env.user not found" >&2
#   echo "Please create a .env.user file. See readme.md for more information" >&2
#   exit 1
# fi

# #===============================================================================
# ### Configuration
# #===============================================================================
# source .env
# source .env.user

# export NGINX_CONFIG=""
# export GATUS_CONFIG=""
# for entry in "${SUBDOMAINS[@]}"; do
#   IFS=';' read -ra split <<< "$entry"
#   subdomain=${split[0]}
#   port=${split[1]}
#   name=${split[2]}
#   health_endpoint=${split[3]}

#   NGINX_CONFIG+=$(generate_nginx_config "$subdomain" "$port")
#   GATUS_CONFIG+=$(generate_gatus_config "$subdomain" "$name" "$health_endpoint")
# done

# #===============================================================================
# ### Container creation
# #===============================================================================
# echo "Creating containers"

# for dir in $(ls services); do
#   echo "Creating or updating containers for $dir"
#   docker-compose -f "services/$dir/docker-compose.yml" up --detach --remove-orphans
# done

# #===============================================================================
# ### Configuration
# #===============================================================================

# # not updating or user has requested certbot update
# if [ "$expand_cert" = true ] || [ "$update" = false ]; then
#   echo "Issuing SSL certificate"

#   # Reload nginx in case the config has changed
#   # Need to reload again after issuing certificate to ensure the latest cert is used
#   reload_nginx

#   # Need to issue a certificate that covers all subdomains
#   docker-compose -f services/nginx/docker-compose.yml run --rm certbot \
#     certonly --webroot --webroot-path=/var/www/certbot \
#     --email ${OWNER_EMAIL} \
#     -d ${DOMAIN_NAME} \
#     $(for subdomain in "${SUBDOMAINS[@]}"; do echo "-d $(get_subdomain $subdomain).${DOMAIN_NAME}"; done)
# fi

# if [ "$update" = false ]; then

#   (
#     echo "Creating superuser for paperless container"
#     cd services/paperlessngx
#     docker-compose run --rm webserver createsuperuser
#   )

#   echo "Configuring borgmatic"
#   docker exec borgmatic borgmatic init --encryption repokey
#   docker exec borgmatic borg key export /mnt/repo > .borg-key.local
#   docker exec borgmatic borg key export ${BORGBASE_URL} > .borg-key.borgbase
# fi

# #===============================================================================
# ### Maintenance
# #===============================================================================

# reload_nginx

# echo "========================================================================="
# echo "Setup complete"
# echo "========================================================================="
# echo "Please back up the following files:"
# echo "  - .env.user"
# echo "  - .borg-key.local"
# echo "  - .borg-key.borgbase"
# echo "See readme.md for remaining setup steps"
