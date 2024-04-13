#!/bin/python3

import docker
from os import environ
import yaml

SRC_FILE = "./conf/AdGuardHome.yaml.base"
DST_FILE = "./conf/AdGuardHome.yaml"

def hash_password(password: str) -> str:
    # TODO: Hash for PHP
    return password


def configure():
    with open(SRC_FILE) as file:
        config = yaml.safe_load(file)
    with open("/tmp/self-hosted-setup/combined-specs.yml") as file:
        specs = yaml.safe_load(file)

    config["users"][0]["name"] = environ["ADGUARD_USERNAME"]
    config["users"][0]["password"] = hash_password(environ["ADGUARD_PASSWORD"])

    config["user_rules"].append(f"{environ['LOCAL_IP']} home.arpa")

    for service, spec in specs.items():
        if "domains" in spec:
            for domain in spec["domains"]:
                config["user_rules"].append(f"{environ['LOCAL_IP']} {domain['domain']}.home.arpa")

    with open(DST_FILE, "w") as file:
        yaml.safe_dump(config, file)

def main():
    configure()

if __name__ == "__main__":
    main()
