use ../../utils/php.nu "php hash_password"

return ({
    ADGUARD_PASSWORD_HASH: (php hash_password $env.ADGUARD_PASSWORD)
} | to yaml)
