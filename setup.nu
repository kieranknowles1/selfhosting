#!/usr/bin/env nu

# TODO: This is getting a bit long, consider splitting it up

use config.nu get_env
use logging.nu *

use utils/cron.nu "cron describe"
use utils/php.nu "php hash_password"
use utils/service.nu ["service list", "service subdomains"]

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

    let datafs = get_fs $environment.DATA_ROOT
    if ($datafs != "btrfs") {
        log warn $"Using non-btrfs filesystems for DATA_ROOT is deprecated, found ($datafs)"
    }

    let domains = service subdomains $environment

    log info $"Using subdomains ($domains | get domain | str join ', ')"

    replace_templates $environment $domains

    log info "Creating containers"
    ($service | default (service list)) | compose_path | each { |compose_file|
        create_container $compose_file $environment $restart
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
    configure_speedtest $environment.DATA_ROOT $environment.OWNER_EMAIL $environment.ADGUARD_PASSWORD $environment.SPEEDTEST_SCHEDULE $environment.SPEEDTEST_RETENTION
    reload_nginx

    log info "========================================================================="
    log info "Setup complete"
    log info "========================================================================="
    log info "Please back up the following files:"
    log info "  - userenv.yml"
    log info "See readme.md for remaining setup steps"
}

def create_container [
    compose_file: string
    environment: record
    restart: bool
] {
    log info $"Creating or updating containers for ($compose_file)"
    let command = if ($restart) {["restart"]} else {["up" "--detach" "--remove-orphans"]}
    with-env $environment {
        run-external docker-compose "-f" $compose_file ...$command
    }
}

def replace_templates [
    environment: record
    domains: list
] {
    log info "Replacing variables in templates"

    let template_env = {
        ...$environment
        ADGUARD_CONFIG: ($domains | generate_adguard_config $environment.LOCAL_IP)
        NGINX_CONFIG: ($domains | generate_nginx_config $environment.DOMAIN_NAME $environment.LOCAL_IP)
        GATUS_CONFIG: ($domains | where includeInStatus | generate_gatus_config $environment.DOMAIN_NAME $environment.HEALTH_TIMEOUT)
        ADGUARD_PASSWORD_HASH: (php hash_password $environment.ADGUARD_PASSWORD)
        SPEEDTEST_SCHEDULE_HUMAN: (cron describe $environment.SPEEDTEST_SCHEDULE)
        MINECRAFT_MODS: (generate_minecraft_mods $environment.MINECRAFT_VERSION)
    }

    ls **/*.template | where not ($it | is-empty) | get name | each {|template|
        log info $"Replacing variables in ($template)"
        let output_file = $template | str replace ".template" ""
        open $template --raw | replace_vars $template_env | save $output_file --force --raw
    }
}

def reload_nginx [] {
    log info "Reloading nginx configuration"
    # Just calling reload doesn't always work, so we'll restart the container
    docker-compose -f ("nginx" | compose_path) restart
}

# Install dependencies and give the current user the needed permissions
def install_deps [] {
    log info "Installing dependencies"
    log info "This requires root privileges"
    sudo apt-get update
    sudo apt-get install -y docker docker-compose restic sqlite3

    sudo npm install --global cronstrue

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
        server_name ($it.domain).($domain_name) ($it.domain).home.arpa;

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

# Generate config to route subdomains of home.arpa to the local IP
def generate_adguard_config [
    local_ip: string
]: list<record<domain: string>> -> string {each {|it| $"
  - ($local_ip) ($it.domain).home.arpa
"} | str join}

# Get the download URL for a mod from Modrinth of a specific Minecraft version
def modrinth_project_download [
    idOrSlug: string
    minecraftVersion: string
]: nothing -> string {
    let url = $"https://api.modrinth.com/v2/project/($idOrSlug)/version?game_versions=[\"($minecraftVersion)\"]&loaders=[\"fabric\"]"

    let response = http get $url
    # NOTE: This assumes the API returns the latest version first
    let files = $response.0.files

    return ($files | get url | str join "\n")
}

# Generate a list of download links for Minecraft mods
def generate_minecraft_mods [
    version: string
]: nothing -> string {[
    (modrinth_project_download fabric-api $version)
    (modrinth_project_download lithium $version)
    (modrinth_project_download bluemap $version)
] | str join "\n"}

# Replace variables in a string
# The special `DOLLAR` variable is used to escape dollar signs
def replace_vars [
    vars: record
] string -> string {
    with-env { ...$vars, DOLLAR: "$" } {
        # TODO: Using envsubst here isn't ideal, can't detect missing variables
        envsubst
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

# Get the format of the filesystem on which a path is located
def get_fs [
    path: string
] nothing -> string {
    # NOTE: This doesn't work if the filesystem contains spaces
    # You have to be insane to use spaces in a file name
    # Only a lunatic would put them in the name of the filesystem itself
    df -T $path | lines | get 1 | split row --regex " +" | get 1
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

# Configure the speedtest container with recommended defaults
# WARN: Credentials MUST come from a trusted source. There are no checks for SQL injection
def configure_speedtest [
    $dataRoot: string,
    $adminEmail: string,
    $adminPassword: string,
    $schedule: string,
    $retention: int
] {
    log info "Configuring speedtest"

    let dbPath = $"($dataRoot)/speedtest/database.sqlite"
    let passwordHash = (php hash_password $adminPassword)

    let commands = [
        # Run speedtest every 15 minutes
        $"UPDATE settings SET payload = \"($schedule)\" WHERE name = \"speedtest_schedule\""
        # Prune old data
        $"UPDATE settings SET payload = ($retention) WHERE name = \"prune_results_older_than\""
        # Secure the admin account
        # TODO: Shouldn't use Wireguard credential vars
        $"UPDATE users SET email = \"($adminEmail)\", password = \"($passwordHash)\" WHERE name = \"Admin\""
    ] | str join ";\n"

    # TODO: The schedule never gets applied. Probably need to manually add the cron job. Have a look at source code
    # to see how it's done
    sudo sqlite3 $dbPath $commands
}
