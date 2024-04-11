#!/bin/python3

from argparse import ArgumentParser
from getpass import getuser
from subprocess import run
from sys import argv
from typing import Any, Literal, overload, Optional
import logging
import os
import yaml

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

def list_services():
    '''List all available services'''
    return os.listdir("services")

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

    def __init__(self):
        self.update: bool
        self.services: list[str]
        self.restart: bool
        self.upgrade: bool

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

@overload
def run_stage(
    stage: Literal["prepare", "afterDeploy"],
    spec: Optional[service.Service],
    env: dict[str, str]
) -> None:
    ...

@overload
def run_stage(
    stage: Literal["configure"],
    spec: Optional[service.Service],
    env: dict[str, str]
) -> Optional[dict[str, Any]]:
    ...

def run_stage(stage: str, spec: Optional[service.Service], env: dict[str, str]):
    if not spec or not "scripts" in spec:
        return
    script = spec["scripts"].get(stage)
    if script is None:
        return

    logger.info(f"Running {stage} script {script}")
    result = run(f"./{script}", check=True, env=env, capture_output=stage == "configure")
    if stage == "configure":
        return yaml.safe_load(result.stdout)

def prepare_global_data():
    '''Prepare global data for service scripts to work with'''

    logger.info("Preparing global data")

    specs = {}
    for item in list_services():
        spec = service.load_spec(f"services/{item}/service.yml")
        if spec:
            specs[item] = spec

    with open("/tmp/self-hosted-setup/combined-specs.yml", "w") as file:
        yaml.safe_dump(specs, file)

def replace_templates(dir: str, env: dict[str, str]):
    '''Replace all templates in the directory and its subdirectories with the environment variables, uses bash ${} syntax'''

    logger.info(f"Replacing templates in {dir}")

    for root, _, files in os.walk(dir):
        for file in files:
            if not file.endswith(".template"):
                continue

            logger.info(f"Replacing templates in {root}/{file}")

            with open(f"{root}/{file}") as template:
                template = template.read()
                for key, value in env.items():
                    template = template.replace(f"${{{key}}}", value)

            with open(f"{root}/{file[:-len('.template')]}", "w") as output:
                output.write(template)

            # Check for unexpanded variables.
            if "${" in template:
                raise ValueError(f"Unexpanded variables in {root}/{file}. Search output file for '${{'")

def deploy_service(dir: str, env: dict[str, str]):
    '''Deploy a service from the services directory, running any necessary scripts.'''
    env = env.copy()
    logger.info(f"Deploying {dir}")
    spec = service.load_spec(f"services/{dir}/service.yml")

    working_dir = os.getcwd()
    try:
        os.chdir(f"services/{dir}")

        run_stage("prepare", spec, env)

        config = run_stage("configure", spec, env)
        if config is not None:
            env.update(config)

        replace_templates(".", env)

        run(
            ["docker-compose", "up", "--build", "--detach", "--remove-orphans"],
            check=True, env=env
        )
        run_stage("afterDeploy", spec, env)
    finally:
        os.chdir(working_dir)

def main():
    args = Args.from_cli()

    if not args.update:
        install_deps()

    str_env = stringify_dict(get_env())

    prepare_global_data()
    for service in args.services:
        deploy_service(service, str_env)

    # TODO: Implement the rest of the script
    run(["./setup.nu"] + argv[1:], check=True)


if __name__ == "__main__":
    main()
