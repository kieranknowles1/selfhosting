#!/bin/python3

from argparse import ArgumentParser
from getpass import getuser
from os import listdir
from subprocess import run
from sys import argv

DEPS = [
    # Backbone of the system
    "docker", "docker-compose",
    # Backups
    "restic",
]

def list_services():
    return listdir("services")

class Args:
    def __init__(self):
        self.update: bool
        self.services: list[str]
        self.restart: bool
        self.upgrade: bool

def parse_args():
    parser = ArgumentParser(
        description="Setup script for self-hosted runner"
    )
    parser.add_argument(
        "--update", "-u", action="store_true",
        help="Update containers without reinstalling everything"
    )
    parser.add_argument(
        "--services", "-s", type=str, nargs="+", default=list_services(),
        choices=list_services(), metavar="service",
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
    args = Args()
    return parser.parse_args(namespace=args)

def install_deps():
    print("Installing dependencies")
    run(["sudo", "apt-get", "update"], check=True)
    run(["sudo", "apt-get", "install", "-y"] + DEPS, check=True)

    print("Giving current user access to docker")
    run(["sudo", "usermod", "-aG", "docker", getuser()], check=True)

def main():
    args = parse_args()

    if not args.update:
        install_deps()

    # TODO: Implement the rest of the script
    run(["./setup.nu"] + argv[1:], check=True)


if __name__ == "__main__":
    main()
