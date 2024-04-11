"""Pre-deployment checks for the application."""

from logging import getLogger
from jsonschema import validate, ValidationError
from typing import Any
import yaml

from utils import service

logger = getLogger(__name__)

def check_schema(schema: Any, data: Any, *, allow_empty: bool = False):
    """
    Check that data is valid according to schema.

    Parameters
    ----------
    :allow_empty: bool
        If True, allow data to be empty.

    Raises
    ------
    :ValidationError:
        If data is invalid.
    """
    if not data and allow_empty:
        return # Nothing to validate, and caller says it's okay

    validate(data, schema)

def check_schemas():
    """Check that service.yml files are valid."""
    logger.info("Checking service schemas")

    with open("schemas/service.schema.yml") as file:
        schema = yaml.safe_load(file)

    errors: list[str] = []

    for item in service.list():
        spec = service.load_spec(f"services/{item}/service.yml")

        try:
            check_schema(schema, spec, allow_empty=True)
        except ValidationError:
            errors.append(f"services/{item}/service.yml does not match schema")

    return errors

def check_all():
    """Run all checks."""
    errors: list[str] = []

    errors.extend(check_schemas())

    # logger.info("All checks passed")

    if len(errors) > 0:
        for error in errors:
            logger.error(error)
        raise Exception("Some checks failed.")
    else:
        logger.info("All checks passed")
