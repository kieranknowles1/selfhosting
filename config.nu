# Get environment variables that can be passed to Docker and other tools
export def get_env []: nothing -> record {{
        CACHE_ROOT: $"(pwd)/cache",
        LOGS_ROOT: $"(pwd)/logs",
        SSHKEYS: $"/home/(whoami)/.ssh",
        LOCAL_IP: (get_local_ip),
        USER_ID: (id -u),
        GROUP_ID: (id -g),
        ...(open $"($env.FILE_PWD)/environment.yml")
        ...(open $"($env.FILE_PWD)/userenv.yml")
}}

# Get the local IP address of the machine
def get_local_ip [] {
    hostname -I | from ssv --noheaders --minimum-spaces 1 | get column1.0
}