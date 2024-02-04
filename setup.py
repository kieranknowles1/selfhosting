#!/bin/python

from argparse import ArgumentParser
from subprocess import run
from os import environ
from os.path import exists
import yaml
import docker

import utils

DEPS = [
    'docker',
    'docker-compose'
]

# Parse command line arguments
def parse_args():
    parser = ArgumentParser(description='Setup script for the project')
    parser.add_argument('--certbot', action='store_true', help='Update/expand SSL certificate')
    parser.add_argument('--update', action='store_true', help='Update containers without reinstalling everything')

    return parser.parse_args()

def check_readiness():
    """
    Check that all prerequisites are met before running the script.

    Raises
    ------
    Exception
        If any of the prerequisites are not met. Message contains the reason.
    """
    if utils.is_root():
        raise Exception('This script should not be run as root.')

    if not exists('secrets.yml'):
        raise Exception('secrets.yml not found. Please create it according to readme.md')

def install_deps():
    """
    Install docker and docker-compose on the system. And give the current user access to docker.
    """
    print('Installing docker and docker-compose')
    run(['sudo', 'apt-get', 'update'])
    run(['sudo', 'apt-get', 'install', '-y', *DEPS])

    print('Giving current user access to docker')
    run(['sudo', 'usermod', '-aG', 'docker', environ['USER']])

def main():
    check_readiness()

    args = parse_args()
    update: bool = args.update
    certbot: bool = args.certbot
    print(args)

    if not update:
        install_deps()

    # Combine variables passed to python with those in environment.yml
    # Prefer the ones passed to python
    environment = {
        **utils.read_yml_env('environment.yml'),
        **utils.read_yml_env('secrets.yml'),
        **environ,
    }
    print(environment)

if __name__ == '__main__':
    main()

# TODO: Port bash to python

# #===============================================================================
# ### Functions
# #===============================================================================
# reload_nginx() {
#   echo "Reloading nginx configuration"
#   docker-compose -f services/nginx/docker-compose.yml exec nginx nginx -s reload
# }

# #===============================================================================
# ### Container creation
# #===============================================================================

# echo "Replacing variables in .template files"
# for file in $(find services -name "*.template"); do
#   echo "Replacing variables in $file"
#   envsubst < $file | sed 's/§/$/g' > ${file%.template}
# done

# echo "Creating containers"

# for dir in ${ALL_SERVICES[@]}; do
#   echo "Creating or updating containers for $dir"
#   docker-compose -f "services/$dir/docker-compose.yml" up --detach --remove-orphans
# done

# #===============================================================================
# ### Configuration
# #===============================================================================

# # not updating or user has requested certbot update
# if [ "$expand_cert" = true ] || [ "$update" = false ]; then
#   echo "Issuing SSL certificate"

#   # Reload nginx in case the config has changed
#   # Need to reload again after issuing certificate to ensure the latest cert is used
#   reload_nginx

#   # Need to issue a certificate that covers all subdomains
#   docker-compose -f services/nginx/docker-compose.yml run --rm certbot \
#     certonly --webroot --webroot-path=/var/www/certbot \
#     --email ${OWNER_EMAIL} \
#     -d ${DOMAIN_NAME} \
#     $(for subdomain in "${SUBDOMAINS[@]}"; do echo "-d ${subdomain}.${DOMAIN_NAME}"; done)
# fi

# if [ "$update" = false ]; then

#   (
#     echo "Creating superuser for paperless container"
#     cd services/paperlessngx
#     docker-compose run --rm webserver createsuperuser
#   )

#   echo "Configuring borgmatic"
#   docker exec borgmatic borgmatic init --encryption repokey
#   docker exec borgmatic borg key export /mnt/repo > .borg-key.local
#   docker exec borgmatic borg key export ${BORGBASE_URL} > .borg-key.borgbase
# fi

# #===============================================================================
# ### Maintenance
# #===============================================================================

# reload_nginx

# echo "========================================================================="
# echo "Setup complete"
# echo "========================================================================="
# echo "Please back up the following files:"
# echo "  - .env.user"
# echo "  - .borg-key.local"
# echo "  - .borg-key.borgbase"
# echo "See readme.md for remaining setup steps"
