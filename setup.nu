#!/usr/bin/env nu

# TODO: This is getting a bit long, consider splitting it up

use audit.nu
use config.nu get_env

use utils/cron.nu "cron describe"
use utils/log.nu *
use utils/script.nu "script run"
use utils/service.nu ["service list", "service subdomains", "service scripts"]

def compose_path [] list<string> -> list<string> {each {|it| $"services/($it)/docker-compose.yml"}}

# Setup script for self-hosted runner
# Installs dependencies and creates containers
export def main [
    --update (-u)    # Update containers without reinstalling everything
    --expand_cert (-e) # Expand the SSL certificate to include new subdomains, even if updating
    --service (-s): string@"service list" # Only update a specific service
    --restart (-r) # Restart the containers instead of updating
] {
    if (is-admin) {
        log error "This script should not be run as root"
        exit 1
    }

    if (not $update) {
        install_deps
    }

    let environment = get_env

    let domains = service subdomains $environment

    log info $"Using subdomains ($domains | get domain | str join ', ')"

    log info "Deploying services"
    $service | default (service list) | each { |service|
        log info $"Deploying ($service)"
        deploy_service $service $environment $restart $domains
    }

    if ((not $update) or $expand_cert) {
        log info "Issuing SSL certificate"
        issue_cert $environment.DOMAIN_NAME ($domains | get domain) $environment.OWNER_EMAIL $environment.DATA_ROOT
    }

    if (not $update) {
        log info "Initializing restic"
        init_restic $environment.RESTIC_REPO $environment.RESTIC_PASSWORD
        init_restic $environment.RESTIC_REMOTE_REPO $environment.RESTIC_PASSWORD

        log info "Creating superuser for paperless container"
        create_paperless_superuser $environment
    }

    configure_cron

    log info "Running basic audit"
    audit

    log info "========================================================================="
    log info "Setup complete"
    log info "========================================================================="
    log info "Please back up the following files:"
    log info "  - userenv.yml"
    log info "See readme.md for remaining setup steps"
    log info "========================================================================="
}

# Create or update a service
def deploy_service [
    service: string
    environment: record
    restart: bool
    domains: list<record<domain: string, includeInStatus: bool, health_endpoint: string>>
] {
    cd $"services/($service)"
    let scripts = $service | service scripts
    let prepare = $scripts.prepare? | default null
    let configure = $scripts.configure? | default null
    let afterDeploy = $scripts.afterDeploy? | default null

    # TODO: Don't pass $environment everywhere and use load-env to start with
    load-env $environment

    $env.GLOBAL_DOMAINS = ($domains | to yaml)

    if ('prepare' in $scripts) {
        script run $scripts.prepare | print
    }
    if ('configure' in $scripts) {
        script run $scripts.configure | save serviceenv.yml --force
    }

    let serviceenv = try { open "serviceenv.yml" } catch { {} }

    replace_templates { ...$environment, ...$serviceenv } $domains
    if ($restart) {
        docker-compose restart
    } else {
        docker-compose up --detach --remove-orphans
    }

    if ('afterDeploy' in $scripts) {
        script run $scripts.afterDeploy | print
    }
}

def replace_templates [
    environment: record
    domains: list # TODO: Remove
] {
    # TODO: All of this should be per service
    let template_env = {
        ...$environment
        GATUS_CONFIG: ($domains | where includeInStatus | generate_gatus_config $environment.DOMAIN_NAME $environment.HEALTH_TIMEOUT)
        SPEEDTEST_SCHEDULE_HUMAN: (cron describe $environment.SPEEDTEST_SCHEDULE)
    }

    # Will be empty if no templates are found
    let templates = try { ls ./**/*.template } catch {[]}

    $templates | where {|it| ($it | describe) != "nothing" } | get name | each {|template|
        log info $"Replacing variables in ($template)"
        let output_file = $template | str replace ".template" ""
        open $template --raw | replace_vars $template_env | save $output_file --force --raw
    }
}

# Install dependencies and give the current user the needed permissions
def install_deps [] {
    log info "Installing dependencies"
    log info "This requires root privileges"
    sudo apt-get update
    sudo apt-get install -y docker docker-compose restic sqlite3 nodejs golang-go

    # Used in cron.nu to provide a human-readable description of cron schedules
    sudo npm install --global cronstrue
    # Used as a replacement for envsubst with strict error checking
    go install github.com/icy/genvsub@latest

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

# Generate the gatus configuration for the services
def generate_gatus_config [
    domain_name: string
    timeout: int # The max response time until a service is considered unhealthy, in milliseconds
]: list<record<domain: string, name: string>> -> string {each {|it| $"
  - name: ($it.name)
    group: Services
    url: https://($it.domain).($domain_name)($it.health_endpoint? | default "/")
    interval: 5m
    client:
        insecure: true
    conditions:
      - \"[STATUS] == 200\"
      - \"[RESPONSE_TIME] < ($timeout)\"
"} | str join}

# Replace variables in a string
def replace_vars [
    vars: record
] string -> string {each {|it|
    $env.PATH = [...$env.PATH, $"(go env GOPATH)/bin"]

    with-env $vars {
        # The "-u" option raises an error if a variable is not defined. Plain envsubst replaces it with an empty string
        let subst = do {
            $it | genvsub -u
        } | complete

        if ($subst.exit_code != 0) {
            log error $"Failed to replace variables. Details: ($subst.stderr)"
        }

        return $subst.stdout
    }
}}

def init_restic [
    repo: string
    password: string
] {
    log info $"Creating restic repository at ($repo)"
    with-env { RESTIC_REPOSITORY: $repo, RESTIC_PASSWORD: $password } {
        sudo -E restic init
    }
}

def create_paperless_superuser [
    $environment
] {
    with-env $environment {
        docker-compose  -f ("paperlessngx" | compose_path) run --rm webserver createsuperuser
    }
}

# Configure cron jobs for maintenance
def configure_cron [] {
    log info "Configuring cron jobs"

    let nuexe = (which nu | get path.0)

    let jobs = ([
        "# Back up nightly at 1 AM"
        $"0 1 * * * root ($nuexe) (pwd)/backup.nu > (pwd)/backup.log 2>&1"
        "# Renew SSL certificate monthly"
        $"0 0 1 * * root ($nuexe) (pwd)/renew.nu > (pwd)/renew.log 2>&1"
    ] | str join "\n") + "\n"

    echo $jobs | save /tmp/cronjobs --force
    sudo chown root:root /tmp/cronjobs
    sudo mv /tmp/cronjobs /etc/cron.d/selfhosted-runner

    sudo systemctl restart cron
}
