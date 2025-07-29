#!/bin/python3

from argparse import ArgumentParser
from getpass import getuser
from subprocess import run
from typing import Any
import logging

from stages import check, prepare, deploy, environment

import utils.service as service

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

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

def main():
    args = Args.from_cli()

    if not args.update:
        install_deps()

    str_env = environment.stringify_dict(environment.get_env())

    try:
        check.check_all()
    except Exception as e:
        if args.loose_checks:
            logger.warning("Some checks failed, continuing anyway")
        else:
            raise e

    prepare.prepare_global_data()

    for service in args.services:
        deploy.deploy_service(service, str_env, args.update)

    # TODO: Implement the rest of the script
    # run(["./setup.nu"] + argv[1:], check=True)


if __name__ == "__main__":
    main()
