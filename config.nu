# Get environment variables that can be passed to Docker and other tools
export def get_env []: nothing -> record {
    let file_config = {
        ...(open $"($env.FILE_PWD)/environment.yml")
        ...(open $"($env.FILE_PWD)/userenv.yml")
    }


    # Append environment with dynamically generated values
    # TODO: Some of these are service specific and should be in that service's config
    # TODO: Maybe also move setup code to per-service config. Cache vars after setup to reload during backups
    return {
        CACHE_ROOT: $"(pwd)/cache",
        LOGS_ROOT: $"(pwd)/logs",
        LOCAL_IP: (get_local_ip),
        USER_ID: (id -u),
        GROUP_ID: (id -g),
        # FIXME: This requires a pack to be set and nginx to be running
        MINECRAFT_RESOURCE_PACK_SHA1: (http get $file_config.MINECRAFT_RESOURCE_PACK | sha1sum | split row " " | get 0),
        # Group that has access to the Docker socket. Use with caution.
        DOCKER_GROUP_ID: (getent group docker | cut "-d:" -f3),
        ...$file_config
}}

# Get the local IP address of the machine
def get_local_ip [] {
    hostname -I | split row " " | get 0
}
