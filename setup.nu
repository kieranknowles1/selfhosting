#!/usr/bin/env nu

use logging.nu *
use services.nu get_services

# Setup script for self-hosted runner
# Installs dependencies and creates containers
def main [
    --update    # Update containers without reinstalling everything"
] {
    if (is-admin) {
        log error "This script should not be run as root"
        exit 1
    }

    if ($update == false) {
        install_deps
    }

    let environment = {
        CACHE_ROOT: $"(pwd)/cache",
        LOGS_ROOT: $"(pwd)/logs",
        SSHKEYS: $"/home/(whoami)/.ssh"
        ...(open environment.yml)
        ...(open userenv.yml)
    }

    let services = get_services $environment

    let nginx_config = $services | each {|s| generate_nginx_config $s $environment.DOMAIN_NAME $environment.LOCAL_IP } | str join
    let gatus_config = $services | each {|s| generate_gatus_config $s $environment.DOMAIN_NAME $environment.HEALTH_TIMEOUT } | str join
    let template_env = {
        ...$environment
        NGINX_CONFIG: $nginx_config
        GATUS_CONFIG: $gatus_config
    }

    ls **/*.template | where not ($it | is-empty) | get name | each {|template|
        log info $"Replacing variables in ($template)"
        let output_file = $template | str replace ".template" ""
        open $template --raw | replace_vars $template_env | save $output_file --force --raw
    }

    log info "Creating containers"
    ls services/*/docker-compose.yml | get name | each { |compose_file|
        log info $"Creating or updating containers for ($compose_file)"
        with-env $environment {
            docker-compose -f ($compose_file) up --detach --remove-orphans
        }
    }

    reload_nginx
}

def reload_nginx [] {
    log info "Reloading nginx configuration"
    docker-compose -f services/nginx/docker-compose.yml exec nginx nginx -s reload
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
    domain_name: string
    local_ip: string
]: nothing -> string {$"
    # ($service.domain), ($service.port)
    server {
        include /etc/nginx/includes/global.conf;
        server_name ($service.domain).($domain_name);

        location / {
            proxy_pass http://($local_ip):($service.port)/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection \"Upgrade\";
        }
    }
"}

# Generate the gatus configuration for a service
def generate_gatus_config [
    service: record<domain: string, name: string>
    domain_name: string
    timeout: int # The max response time until a service is considered unhealthy, in milliseconds
]: nothing -> string {$"
  - name: ($service.name)
    group: Services
    url: https://($service.domain).($domain_name)($service.health_endpoint? | default "/")
    interval: 5m
    conditions:
      - \"[STATUS] == 200\"
      - \"[RESPONSE_TIME] < ($timeout)\"
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
