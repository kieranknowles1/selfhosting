from typing import Any
from os import getuid, getgid
import yaml

SETTINGS = {
    # TODO: This may not be necessary, caches are ephemeral by definition and containers can keep
    # cache in themselves which is also ephemeral
    "CACHE_ROOT": "/tmp/self-hosted-runner/cache",
    # TODO: Logs are tracked by docker itself, so probably don't need to be stored elsewhere
    "LOGS_ROOT": "/tmp/self-hosted-runner/logs",
    "USER_ID": getuid(),
    "GROUP_ID": getgid(),
}


def stringify_value(value: Any) -> str:
    """Convert a value to a string"""

    if isinstance(value, list):
        # TODO: Handle commas in list items
        return ",".join(str(item) for item in value)  # type: ignore item is unknown, but we're converting it to a string anyway
    return str(value)


def stringify_dict(env: dict[str, Any]) -> dict[str, str]:
    """Convert all values in the dictionary to strings"""
    return {key: stringify_value(value) for key, value in env.items()}


def get_env() -> dict[str, Any]:
    """Get the combined hardcoded defaults, settings, and user secrets for the environment"""
    env = SETTINGS.copy()
    with open("environment.yml") as file:
        env.update(yaml.safe_load(file))
    with open("userenv.yml") as file:
        env.update(yaml.safe_load(file))
    return env
