use ../../utils/log.nu "log info"

let update = $env.GLOBAL_ISUPDATE == 'true'

# Create a superuser with admin rights over the container
def create_superuser [] {
    docker-compose run --rm webserver createsuperuser
}

if ($update == false) {
    log info "Creating superuser"
    create_superuser
}
