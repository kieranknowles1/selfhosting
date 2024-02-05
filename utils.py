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
    The env file is expected to be a dictionary of string-string pairs.

    Parameters
    ----------
    path : str
        Path to the yaml file.

    Returns
    -------
    Dict[str, str]
        The contents of the yaml file as a dictionary.
    """
    with open(path, "r") as file:
        return yaml.safe_load(file)
