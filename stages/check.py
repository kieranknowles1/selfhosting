"""Pre-deployment checks for the application."""

from logging import getLogger
from jsonschema import validate, ValidationError
import yaml

from utils import service

logger = getLogger(__name__)

def check_schemas():
    """Check that service.yml files are valid."""
    logger.info("Checking service schemas")

    with open("schemas/service.schema.yml") as file:
        schema = yaml.safe_load(file)

    for item in service.list():
        spec = service.load_spec(f"services/{item}/service.yml")

        # An empty spec is valid
        if spec:
            try:
                validate(spec, schema)
            except ValidationError as e:
                logger.error(f"Service {item} has an invalid service.yml file")
                raise e

def check_all():
    """Run all checks."""
    check_schemas()
    logger.info("All checks passed")
