#!/bin/python3

from os import environ
from typing import Any
import yaml

def configure_reverse_proxy(service: str, domain: dict[str, Any]):
    port = environ[domain["portVar"]]
    return f"""
        # {service}, {domain["domain"]}.{environ["DOMAIN_NAME"]} -> {environ["LOCAL_IP"]}:{port}
        server {{
            include /etc/nginx/includes/global.conf;
            server_name {domain["domain"]}.{environ["DOMAIN_NAME"]} {domain["domain"]}.home.arpa;

            location / {{
                proxy_pass http://{environ["LOCAL_IP"]}:{port}/;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "Upgrade";
            }}
        }}
    """

def generate_config():
    with open("/tmp/self-hosted-setup/combined-specs.yml") as file:
        specs = yaml.safe_load(file)

    proxies = []
    for service, spec in specs.items():
        if "domains" in spec:
            for domain in spec["domains"]:
                proxies.append(configure_reverse_proxy(service, domain))

    return "\n".join(proxies)

def main():
    return {
        "NGINX_CONFIG": generate_config()
    }

if __name__ == "__main__":
    print(yaml.safe_dump(main()))
