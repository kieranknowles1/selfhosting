#!/usr/bin/env python3

from os import environ
import yaml

# TODO: Is there a htpasswd library for Python?
from subprocess import run

SRC_FILE = "./conf/AdGuardHome.yaml.base"
DST_FILE = "./conf/AdGuardHome.yaml"

def hash_password(username: str, password: str) -> str:
    result = run(
        ["htpasswd", "-B", "-C", "10", "-n", "-b", username, password],
        capture_output=True,
        text=True,
        check=True
    ).stdout.strip()

    return result.split(":")[1]


def configure():
    with open(SRC_FILE) as file:
        config = yaml.safe_load(file)
    with open("/tmp/self-hosted-setup/combined-specs.yml") as file:
        specs = yaml.safe_load(file)

    config["users"][0]["name"] = environ["ADGUARD_USERNAME"]
    config["users"][0]["password"] = hash_password(environ["ADGUARD_USERNAME"], environ["ADGUARD_PASSWORD"])

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
