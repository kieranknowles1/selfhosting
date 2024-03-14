#!/usr/bin/env nu

use utils/log.nu ["log info", "log warn"]

# Run a basic security check on containers
export def main [] {
    let num_root = docker ps --format '{{ .Names }}' | lines | each {|it|
        let is_root = audit container is_root $it
        if $is_root {
            log warn $"Container ($it) is running as root"
        }
        return $is_root
    } | where {|at| $at} | length

    log info $"($num_root) containers are running as root"
}

# Get if the container is running as root
export def "audit container is_root" [
    container: string
] string -> bool {
    let id = docker exec $container id -u
    return ($id == "0")
}
