#!/bin/python3

from argparse import ArgumentParser
from getpass import getuser
from subprocess import run
from sys import argv
from typing import Any
import logging
import os
import yaml

from stages import check, prepare, deploy

import utils.service as service

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

SETTINGS = {
    # TODO: This may not be necessary, caches are ephemeral by definition and containers can keep
    # cache in themselves which is also ephemeral
    "CACHE_ROOT": "/tmp/self-hosted-runner/cache",
    # TODO: Logs are tracked by docker itself, so probably don't need to be stored elsewhere
    "LOGS_ROOT": "/tmp/self-hosted-runner/logs",
    "USER_ID": os.getuid(),
    "GROUP_ID": os.getgid(),
}

DEPS = [
    # Backbone of the system
    "docker", "docker-compose",
    # Backups
    "restic",
]

class Args:
    '''Strongly typed arguments for the script'''

    @staticmethod
    def from_cli():
        parser = ArgumentParser(
            description="Setup script for self-hosted runner"
        )
        parser.add_argument(
            "--update", "-u", action="store_true",
            help="Update containers without reinstalling everything"
        )
        parser.add_argument(
            "--services", "-s", type=str, nargs="+", default=service.list(),
            choices=service.list(), metavar="service",
            help="Only update the specified services from the services directory."
        )
        parser.add_argument(
            "--restart", "-r", action="store_true",
            help="Restart the containers instead of updating"
        )
        parser.add_argument(
            "--upgrade", "-U", action="store_true",
            help="Upgrade containers to their latest versions"
        )
        parser.add_argument(
            "--loose-checks", "-C", action="store_true",
            help="Allow the script to continue even if some checks fail"
        )
        args = Args()
        return parser.parse_args(namespace=args)

    def __init__(self):
        self.update: bool
        self.services: list[str]
        self.restart: bool
        self.upgrade: bool
        self.loose_checks: bool

def install_deps():
    logger.info("Installing dependencies")
    run(["sudo", "apt-get", "update"], check=True)
    run(["sudo", "apt-get", "install", "-y"] + DEPS, check=True)

    logger.info("Giving current user access to docker")
    run(["sudo", "usermod", "-aG", "docker", getuser()], check=True)

def get_env() -> dict[str, Any]:
    '''Get the combined hardcoded defaults, settings, and user secrets for the environment'''
    env = SETTINGS.copy()
    with open("environment.yml") as file:
        env.update(yaml.safe_load(file))
    with open("userenv.yml") as file:
        env.update(yaml.safe_load(file))
    return env

def stringify_dict(env: dict[str, Any]) -> dict[str, str]:
    '''Convert all values in the dictionary to strings'''
    return {key: str(value) for key, value in env.items()}

def main():
    args = Args.from_cli()

    if not args.update:
        install_deps()

    str_env = stringify_dict(get_env())

    try:
        check.check_all()
    except Exception as e:
        if args.loose_checks:
            logger.warning("Some checks failed, continuing anyway")
        else:
            raise e

    prepare.prepare_global_data()

    for service in args.services:
        deploy.deploy_service(service, str_env)

    # TODO: Implement the rest of the script
    run(["./setup.nu"] + argv[1:], check=True)


if __name__ == "__main__":
    main()
