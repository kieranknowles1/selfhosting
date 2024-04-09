#!/usr/bin/env nu

use audit.nu
use config.nu get_env

use utils/log.nu *
use utils/script.nu "script run"
use utils/service.nu ["service list", "service subdomains", "service scripts", "service generatedconfig"]

# Setup script for self-hosted runner
# Installs dependencies and creates containers
export def main [
    --update (-u)    # Update containers without reinstalling everything
    --service (-s): string@"service list" # Only update a specific service
    --restart (-r) # Restart the containers instead of updating
    --upgrade (-U) # Upgrade containers to their latest versions
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

    log info "Deploying services"
    $service | default (service list) | each { |service|
        log info $"Deploying ($service)"
        deploy_service $service $environment $domains --update=$update --restart=$restart --upgrade=$upgrade
    }

    if (not $update) {
        log info "Initializing restic"
        init_restic $environment.RESTIC_REPO $environment.RESTIC_PASSWORD
        init_restic $environment.RESTIC_REMOTE_REPO $environment.RESTIC_PASSWORD
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
    domains: list<record<domain: string, includeInStatus: bool, health_endpoint: string>>
    --update
    --restart
    --upgrade
] {
    cd $"services/($service)"
    let scripts = $service | service scripts
    load-env $environment

    $env.GLOBAL_DOMAINS = ($domains | to yaml)
    $env.GLOBAL_ISUPDATE = ($update | into string)

    if ('prepare' in $scripts) {
        script run $scripts.prepare | print
    }
    if ('configure' in $scripts) {
        script run $scripts.configure | save serviceenv.yml --force
        # Protect the file
        chmod 600 serviceenv.yml
    }

    let serviceenv = service generatedconfig $service
    load-env $serviceenv

    if ($upgrade) {
        docker-compose pull
    }

    replace_templates { ...$environment, ...$serviceenv }
    if ($restart) {
        docker-compose restart
    } else {
        docker-compose up --detach --remove-orphans
    }

    if ('afterDeploy' in $scripts) {
        # FIXME: This doesn't check for exit code, but "script run" suppresses stdout until the script is complete
        # Paperless requires user input
        run-external nu $scripts.afterDeploy
    }
}

def replace_templates [
    environment: record
] {
    # Will be empty if no templates are found
    let templates = try { ls ./**/*.template } catch {[]}

    $templates | where {|it| ($it | describe) != "nothing" } | get name | each {|template|
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
    (sudo apt-get install -y
        # Backbone of the system
        docker
        docker-compose
        # Backups
        restic
        # Configure some services after deployment
        sqlite3
        # For cronstrue
        nodejs
    )

    # Describe cron expressions in human readable formats
    sudo npm install -g cronstrue

    log info "Giving current user access to docker"
    sudo usermod -aG docker $env.USER
}

# Replace variables in a string
def replace_vars [
    vars: record
] string -> string {each {|it|
    mut out = $it

    for $entry in ($vars | transpose key value) {
        let bash_var = $"${($entry.key)}"

        let edit = $out | str replace --all $bash_var ($entry.value | into string)
        $out = $edit
    }

    # Check that everything was replaced
    # NOTE: This does not support `${` in replacement strings
    let start = $out | str index-of "${"
    if ($start != -1) {
        let end = $out | str index-of "}" --range $start..
        let name = $out | str substring $start..($end + 1)

        error make {
            msg: $"Variable ($name) not replaced",
            variable: $name,
        }
    }


    return $out
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

# Configure cron jobs for maintenance
def configure_cron [] {
    log info "Configuring cron jobs"

    let nuexe = (which nu | get path.0)

    let jobs = ([
        "# Back up nightly at 1 AM"
        $"0 1 * * * root ($nuexe) (pwd)/backup.nu > (pwd)/backup.log 2>&1"
        "# Renew SSL certificate monthly"
        $"0 0 1 * * root ($nuexe) (pwd)/renew.nu > (pwd)/renew.log 2>&1"
        "# Update services every Monday at midnight"
        $"0 0 * * 1 (whoami) ($nuexe) (pwd)/setup.nu --update --upgrade > (pwd)/update.log 2>&1"
    ] | str join "\n") + "\n"

    echo $jobs | save /tmp/cronjobs --force
    sudo chown root:root /tmp/cronjobs
    sudo mv /tmp/cronjobs /etc/cron.d/selfhosted-runner

    sudo systemctl restart cron
}
