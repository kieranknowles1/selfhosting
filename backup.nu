#!/usr/bin/env nu
# Backup script for self-hosted runner
# Pauses containers, runs Restic, and resumes containers
# WARN: If a backup fails, containers will not be resumed. A server reboot is recommended in this case
# Should be run as root

use config.nu get_env
use utils/log.nu *
use utils/service.nu ["service usingdata", "service generatedconfig"]

if not (is-admin) {
    log error "This script must be run as root"
    exit 1
}

let environment = get_env
let toPause = service usingdata

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

let start = (date now)
log info "========================="
log info " --- Starting backup --- "
log info $"Backup started at ($start)"
log info "========================="

log info "Containers going PAUSED for backup"
for service in $toPause {
    log info $"Pausing ($service)"
    with-env { ...$environment, ...(service generatedconfig $service) } {
        docker-compose --file $"($env.FILE_PWD)/services/($service)/docker-compose.yml" pause
    }
}

log info "Containers paused. Starting backup"
create_backup $environment.RESTIC_REPO $environment.RESTIC_PASSWORD $environment.DATA_ROOT
create_backup $environment.RESTIC_REMOTE_REPO $environment.RESTIC_PASSWORD $environment.DATA_ROOT


log info "Containers going UNPAUSED after backup"
for service in $toPause {
    log info $"Unpausing ($service)"
    with-env { ...$environment, ...(service generatedconfig $service) } {
        docker-compose --file $"($env.FILE_PWD)/services/($service)/docker-compose.yml" unpause
    }
}

log info $"Backup complete. Took ((date now) - $start)"
