#!/bin/python3

from os import environ
from typing import Any
import json
import yaml

def generate_commands(specs: dict[str, Any]):
    seen_hotkeys = dict()

    commands = []
    for service, spec in specs.items():
        if "domains" in spec:
            for domain in spec["domains"]:

                hotkey = domain["hotkey"]
                if hotkey in seen_hotkeys:
                    raise ValueError(f'Hotkey "{hotkey}" is already in use by {seen_hotkeys.get(hotkey)}')
                seen_hotkeys[hotkey] = domain["domain"]

                value = {
                    "url": f"https://{domain['domain']}.{environ['DOMAIN_NAME']}",
                    "name": domain["shortPurpose"] if "shortPurpose" in domain else domain["name"],
                }
                if "icon" in domain:
                    value["icon"] = domain["icon"]

                commands.append([hotkey, value])

    return commands

def main():
    with open("/tmp/self-hosted-setup/combined-specs.yml") as file:
        specs = yaml.safe_load(file)

    commands = generate_commands(specs)
    with open("commands.generated.json", "w") as file:
        json.dump(commands, file, indent=2)

if __name__ == "__main__":
    main()
