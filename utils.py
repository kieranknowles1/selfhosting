from os import geteuid
from typing import Dict
import yaml


def is_root() -> bool:
    """
    Check if the current user is root.

    Returns
    -------
    bool
        True if the current user is root, False otherwise.
    """
    return geteuid() == 0


def read_yml_env(path: str) -> Dict[str, str]:
    """
    Read a yaml file and return it as a dictionary.
    All keys must be strings.
    All values must be strings, numbers, or booleans. Non-string values will be converted to strings.

    Parameters
    ----------
    path : str
        Path to the yaml file.

    Returns
    -------
    Dict[str, str]
        The contents of the yaml file as a dictionary.

    Raises
    ------
    Exception
        If the file at `path` is not a valid yaml file or
        if the file at `path` is not a dictionary of string-string pairs.
    """

    with open(path, "r") as file:
        env = yaml.safe_load(file)

    if not isinstance(env, dict):
        raise Exception(f"{path} is not a dictionary.")
    for key, value in env.items():
        if not isinstance(key, str):
            raise Exception(f"{path} {key} is not a string.")

        # Convert values to strings.
        if isinstance(value, str):
            continue
        elif isinstance(value, int) or isinstance(value, float):
            env[key] = str(value)
        elif isinstance(value, bool):
            env[key] = "true" if value else "false"
        else:
            raise Exception(f"{path} {key} is not a string, number, or boolean.")

    return env
