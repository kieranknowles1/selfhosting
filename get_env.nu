# Get environment variables that can be passed to Docker and other tools
export def main []: nothing -> record {{
        CACHE_ROOT: $"(pwd)/cache",
        LOGS_ROOT: $"(pwd)/logs",
        SSHKEYS: $"/home/(whoami)/.ssh",
        LOCAL_IP: (get_local_ip),
        ...(open environment.yml)
        ...(open userenv.yml)
}}

# Get the local IP address of the machine
def get_local_ip [] {
    hostname -I | from ssv --noheaders --minimum-spaces 1 | get column1.0
}
