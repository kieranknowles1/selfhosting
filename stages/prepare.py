"""Prepare the deployment of the application."""

from logging import getLogger
from os import makedirs
import yaml

import utils.service as service

logger = getLogger(__name__)

def prepare_global_data():
    '''
    Prepare global data for service scripts to work with

    Writes to /tmp/self-hosted-setup/
    '''

    logger.info("Preparing global data")

    specs = {}
    for item in service.list():
        spec = service.load_spec(f"services/{item}/service.yml")
        if spec:
            specs[item] = spec

    makedirs("/tmp/self-hosted-setup", exist_ok=True)
    with open("/tmp/self-hosted-setup/combined-specs.yml", "w") as file:
        yaml.safe_dump(specs, file)
