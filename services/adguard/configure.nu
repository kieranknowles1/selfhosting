use ../../utils/php.nu "php hash_password"

# Generate config to route subdomains of home.arpa to the local IP
def generate_config []: {
    $env.GLOBAL_DOMAINS | from yaml | each {|it| $"
  - ($env.LOCAL_IP) ($it.domain).home.arpa
"} | str join}

return ({
    ADGUARD_CONFIG: (generate_config)
    ADGUARD_PASSWORD_HASH: (php hash_password $env.ADGUARD_PASSWORD)
} | to yaml)
