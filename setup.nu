#!/usr/bin/env nu

use get_env.nu
use logging.nu *
use services.nu get_services

# Setup script for self-hosted runner
# Installs dependencies and creates containers
def main [
    --update    # Update containers without reinstalling everything
    --expand_cert # Expand the SSL certificate to include new subdomains, even if updating
] {
    if (is-admin) {
        log error "This script should not be run as root"
        exit 1
    }

    if (not $update) {
        install_deps
    }

    let environment = get_env

    let services = get_services $environment

    let template_env = {
        ...$environment
        NGINX_CONFIG: ($services | generate_nginx_config $environment.DOMAIN_NAME $environment.LOCAL_IP)
        GATUS_CONFIG: ($services | generate_gatus_config $environment.DOMAIN_NAME $environment.HEALTH_TIMEOUT)
    }

    ls **/*.template | where not ($it | is-empty) | get name | each {|template|
        log info $"Replacing variables in ($template)"
        let output_file = $template | str replace ".template" ""
        replace_vars (open $template --raw) $template_env | save $output_file --force --raw
    }

    log info "Creating containers"
    ls services/*/docker-compose.yml | get name | each { |compose_file|
        log info $"Creating or updating containers for ($compose_file)"
        with-env $environment {
            docker-compose -f ($compose_file) up --detach --remove-orphans
        }
    }

    if ((not $update) or $expand_cert) {
        log info "Issuing SSL certificate"
        with-env $environment {
            issue_cert $environment.DOMAIN_NAME ($services | get domain) $environment.OWNER_EMAIL $environment.DATA_ROOT
        }
    }

    if (not $update) {
        log info "Initializing restic"
        init_restic $environment.RESTIC_REPO $environment.RESTIC_PASSWORD
        init_restic $environment.RESTIC_REMOTE_REPO $environment.RESTIC_PASSWORD
    }

    reload_nginx

    log info "========================================================================="
    log info "Setup complete"
    log info "========================================================================="
    log info "Please back up the following files:"
    log info "  - userenv.yml"
    log info "See readme.md for remaining setup steps"
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
    sudo apt-get install -y docker docker-compose restic

    log info "Giving current user access to docker"
    sudo usermod -aG docker $env.USER
}

# Issue a SSL certificate for the domain name
def issue_cert [
    domain: string
    subdomains: list<string>
    email: string
    data_root: string
] {
    # Make sure we're on the latest nginx config
    reload_nginx

    log info $"Issuing SSL certificates to cover subdomains ($subdomains | str join ', ')"

    (run-external sudo docker run "-it" "--rm" "--name" certbot
        "-v" $"($data_root)/nginx/certbot/www:/var/www/certbot"
        "-v" $"($data_root)/nginx/certbot/conf:/etc/letsencrypt"
        "certbot/certbot" certonly
        "--webroot" "--webroot-path=/var/www/certbot"
        "-d" $domain
        ...($subdomains | each { |subdomain|
            ["-d" $"($subdomain).($domain)"]
        } | flatten)
    )
}

# Generate the nginx configuration for the services
def generate_nginx_config [
    domain_name: string
    local_ip: string
]: list<record<domain: string, port: int>> -> string {each {|it| $"
    # ($it.domain), ($it.port)
    server {
        include /etc/nginx/includes/global.conf;
        server_name ($it.domain).($domain_name);

        location / {
            proxy_pass http://($local_ip):($it.port)/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection \"Upgrade\";
        }
    }
"} | str join}

# Generate the gatus configuration for the services
def generate_gatus_config [
    domain_name: string
    timeout: int # The max response time until a service is considered unhealthy, in milliseconds
]: list<record<domain: string, name: string>> -> string {each {|it| $"
  - name: ($it.name)
    group: Services
    url: https://($it.domain).($domain_name)($it.health_endpoint? | default "/")
    interval: 5m
    conditions:
      - \"[STATUS] == 200\"
      - \"[RESPONSE_TIME] < ($timeout)\"
"} | str join}

def replace_vars [
    raw: string
    vars: record
] nothing -> string {
    with-env $vars {
        # TODO: Using envsubst here isn't ideal, can't detect missing variables
        $raw | envsubst
    }
}

def init_restic [
    repo: string
    password: string
] {
    log info $"Creating restic repository at ($repo)"
    with-env { RESTIC_REPOSITORY: $repo, RESTIC_PASSWORD: $password } {
        sudo -E restic init
    }
}

# TODO: Rewrite for nushell
# #===============================================================================
# ### Configuration
# #===============================================================================

# if [ "$update" = false ]; then

#   (
#     echo "Creating superuser for paperless container"
#     cd services/paperlessngx
#     docker-compose run --rm webserver createsuperuser
#   )
# fi

# #===============================================================================
# ### Maintenance
# #===============================================================================

# reload_nginx
