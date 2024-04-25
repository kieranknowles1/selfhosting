#!/usr/bin/env nu

### !!!! DO NOT USE DIRECTLY !!!! ###
# This script is DEPRECATED. Functionality is being REMOVED as it gets ported to Python.

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

    let environment = get_env

    let domains = service subdomains $environment

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
        $"0 1 * * * root /bin/python3 (pwd)/backup.py > (pwd)/backup.log 2>&1"
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
