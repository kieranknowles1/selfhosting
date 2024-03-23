# Generate a htpasswd compliant password hash
def hash_password [] {
    # TODO: Don't reuse vars, try sso
    let password = $env.ADGUARD_PASSWORD

    openssl passwd -apr1 -salt (openssl rand -base64 16) $password
}

return ({
    WUD_PASSWORD_HASH: (hash_password)
} | to yaml)
