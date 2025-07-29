#!/usr/bin/env python3

from os import environ
import yaml

SRC_FILE = "config/config.yaml.base"
DST_FILE = "config/config.yaml"

def create_endpoint(spec: dict[str, str]):
    health_endpoint = spec.get("health_endpoint", "/")

    return {
        "name": spec["name"],
        "group": "Services",
        "url": f"https://{spec['domain']}.{environ['DOMAIN_NAME']}{health_endpoint}",
        "interval": "5m",
        "client": {
            "insecure": True
        },
        "conditions": [
            "[STATUS] == 200",
            f"[RESPONSE_TIME] < {environ['HEALTH_TIMEOUT']}"
        ]
    }

def configure_gatus():
    with open(SRC_FILE, 'r') as stream:
        data = yaml.safe_load(stream)
    with open("/tmp/self-hosted-setup/combined-specs.yml") as file:
        specs = yaml.safe_load(file)

    data["endpoints"][0]["url"] = f"https://{environ['DOMAIN_NAME']}"

    for service, spec in specs.items():
        if "domains" in spec:
            for domain in spec["domains"]:
                data["endpoints"].append(create_endpoint(domain))

    with open(DST_FILE, 'w') as stream:
        yaml.safe_dump(data, stream)

def main():
    configure_gatus()

if __name__ == "__main__":
    main()

# Generate the gatus configuration for the services
# NOTE: This is YAML, so indentation matters
# def generate_gatus_config [] {
#     $env.GLOBAL_DOMAINS | from yaml | each {|it| $"
#   - name: ($it.name)
#     group: Services
#     url: https://($it.domain).($env.DOMAIN_NAME)($it.health_endpoint? | default "/")
#     interval: 5m
#     client:
#         insecure: true
#     conditions:
#       - \"[STATUS] == 200\"
#       - \"[RESPONSE_TIME] < ($env.HEALTH_TIMEOUT)\"
# "} | str join}

# return ({
#     GATUS_CONFIG: (generate_gatus_config)
# } | to yaml)
