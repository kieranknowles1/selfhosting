#!/bin/python3

from hashlib import sha256
from os import environ
import yaml

print(yaml.safe_dump({
    "WUD_PASSWORD_HASH": sha256(environ["ADGUARD_PASSWORD"].encode()).hexdigest()
}))
