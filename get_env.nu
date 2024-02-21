# Get environment variables that can be passed to Docker and other tools
export def main []: nothing -> record {{
        CACHE_ROOT: $"(pwd)/cache",
        LOGS_ROOT: $"(pwd)/logs",
        SSHKEYS: $"/home/(whoami)/.ssh"
        ...(open environment.yml)
        ...(open userenv.yml)
}}
