# Get environment variables that can be passed to Docker and other tools
export def get_env []: nothing -> record {
    let file_config = {
        ...(open $"($env.FILE_PWD)/environment.yml")
        ...(open $"($env.FILE_PWD)/userenv.yml")
    }


    # Append environment with dynamically generated values
    return {
        # TODO: This and logs shouldn't leave the containers
        CACHE_ROOT: $"(pwd)/cache",
        LOGS_ROOT: $"(pwd)/logs",
        USER_ID: (id -u),
        GROUP_ID: (id -g),
        # Group that has access to the Docker socket. Use with caution.
        DOCKER_GROUP_ID: (getent group docker | cut "-d:" -f3),
        ...$file_config
}}

# Get the local IP address of the machine
def get_local_ip [] {
    hostname -I | split row " " | get 0
}
