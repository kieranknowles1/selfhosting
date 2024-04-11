#!/bin/python3

from os import environ
from typing import Any
import json
import yaml

def generate_commands(specs: dict[str, Any]):
    commands = []
    for service, spec in specs.items():
        if "domains" in spec:
            for domain in spec["domains"]:
                # TODO: Shortcut field
                # TODO: Icon
                shortcut = domain["domain"][0:2]
                commands.append([shortcut, {
                    "url": f"https://{domain['domain']}.{environ['DOMAIN_NAME']}",
                    "name": domain["name"],
                }])

    return commands

def main():
    with open("/tmp/self-hosted-setup/combined-specs.yml") as file:
        specs = yaml.safe_load(file)

    commands = generate_commands(specs)
    with open("commands.generated.json", "w") as file:
        json.dump(commands, file, indent=2)

if __name__ == "__main__":
    main()
