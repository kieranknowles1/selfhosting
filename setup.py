#!/bin/python

from argparse import ArgumentParser
from subprocess import run
from os import environ, walk, listdir
from os.path import exists
from typing import Dict

import utils

COMPOSE_PROJECT_NAME = "self-hosted"
DEPS = ["docker", "docker-compose"]


# Parse command line arguments
def parse_args():
    parser = ArgumentParser(description="Setup script for the project")
    parser.add_argument(
        "--certbot", action="store_true", help="Update/expand SSL certificate"
    )
    parser.add_argument(
        "--update",
        action="store_true",
        help="Update containers without reinstalling everything",
    )

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
        raise Exception("This script should not be run as root.")

    if not exists("secrets.yml"):
        raise Exception(
            "secrets.yml not found. Please create it according to readme.md"
        )


def install_deps():
    """
    Install docker and docker-compose on the system. And give the current user access to docker.
    """
    print("Installing docker and docker-compose")
    run(["sudo", "apt-get", "update"], check=True)
    run(["sudo", "apt-get", "install", "-y", *DEPS], check=True)

    print("Giving current user access to docker")
    run(["sudo", "usermod", "-aG", "docker", environ["USER"]])


def replace_template_vars(environment: Dict[str, str]):
    """
    Replace variables in .template files with their values.

    Templates are expected to use Bash syntax for variables, braces are mandatory.
    """
    print("Replacing variables in .template files")
    for base, _, files in walk("services"):
        for file in files:
            path = f"{base}/{file}"
            if path.endswith(".template"):
                print(f"Replacing variables in {path}")
                with open(path, "r") as f:
                    content = f.read()
                output_path = path[: -len(".template")]
                with open(output_path, "w") as f:
                    f.write(content.format(**environment))


def compose_up(env: Dict[str, str], service: str):
    """
    Run docker-compose up for the service at /services/$service

    Parameters
    ----------
    env : Dict[str, str]
        The environment variables to use for the service.
    service : str
        The name of the service to run docker-compose up for.
    """
    print(f"Creating or updating containers for {service}")
    run(
        [
            "docker-compose",
            "-f",
            f"services/{service}/docker-compose.yml",
            "up",
            "--detach",
            "--remove-orphans",
        ],
        check=True,
        env=env,
    )


def main():
    check_readiness()

    args = parse_args()
    update: bool = args.update
    certbot: bool = args.certbot

    if not update:
        install_deps()

    # Combine variables passed to python with those in environment.yml
    # Prefer the ones passed to python
    environment = {
        **utils.read_yml_env("environment.yml"),
        **utils.read_yml_env("secrets.yml"),
        **environ,
        COMPOSE_PROJECT_NAME: COMPOSE_PROJECT_NAME,
    }
    print(environment)

    replace_template_vars(environment)

    for service in listdir("services"):
        compose_up(environment, service)


if __name__ == "__main__":
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
