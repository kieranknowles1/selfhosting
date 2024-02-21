#!/usr/bin/env nu
# Backup script for self-hosted runner
# Pauses containers, runs Restic, and resumes containers
# WARN: If a backup fails, containers will not be resumed. A server reboot is recommended in this case
# Should be run as root

use get_env.nu
use logging.nu "log info"
use services.nu get_services

let environment = get_env
let services = get_services $environment

def create_backup [
    repo: string,
    password: string,
    source: string,
] {
    log info $"Starting backup of ($source) to ($repo)"
    with-env { RESTIC_REPOSITORY: $repo, RESTIC_PASSWORD: $password } {
        restic backup $source
    }
}

log info "========================="
log info " --- Starting backup --- "
log info $"Backup started at (date now)"
log info "========================="

log info "Containers going PAUSED for backup"
for service in $services {
    if ($service.backup_pause? == true) {
        log info $"Pausing ($service.name)"
        with-env $environment {
            docker-compose --file $"services/($service.directory)/docker-compose.yml" pause
        }
    }
}

log info "Containers paused. Starting backup"
create_backup $environment.RESTIC_REPO $environment.RESTIC_PASSWORD $environment.DATA_ROOT | tee -a backup.log


log info "Containers going UNPAUSED after backup"
for service in $services {
    if ($service.backup_pause? == true) {
        log info $"Unpausing ($service.name)"
        with-env $environment {
            docker-compose --file $"services/($service.directory)/docker-compose.yml" unpause
        }
    }
}

log info $"Backup complete at (date now)"
