use ../../utils/log.nu "log info"

let update = $env.GLOBAL_ISUPDATE == 'true'

# Issue a SSL certificate for the domain name
# FIXME: This currently doesn't replace the old certificate when expanding
# and currently needs some finnicking to get the new one working
def issue_cert [] {
    let subdomains = $env.GLOBAL_DOMAINS | from yaml | get domain

    log info $"Issuing SSL certificates to cover subdomains ($subdomains | str join ', ')"

    (run-external docker run "-it" "--rm" "--name" certbot
        "-v" $"($env.DATA_ROOT)/nginx/certbot/www:/var/www/certbot"
        "-v" $"($env.DATA_ROOT)/nginx/certbot/conf:/etc/letsencrypt"
        "certbot/certbot" certonly
        "--webroot" "--webroot-path=/var/www/certbot"
        "-d" $env.DOMAIN_NAME
        ...($subdomains | each { |subdomain|
            ["-d" $"($subdomain).($env.DOMAIN_NAME)"]
        } | flatten)
    )
}

# Make sure the latest config is loaded
docker-compose exec nginx nginx -s reload

if ($update == false) {
    log info "Issuing SSL certificate"
    issue_cert
}
