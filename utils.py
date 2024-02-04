from os import geteuid
from typing import Dict
import yaml

def is_root() -> bool:
    return geteuid() == 0

def read_yml_env(path: str) -> Dict[str, str]:
    with open(path, 'r') as file:
        return yaml.safe_load(file)
