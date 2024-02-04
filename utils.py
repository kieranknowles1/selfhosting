from os import geteuid
import yaml

def is_root() -> bool:
    return geteuid() == 0

def read_yml_env(path: str) -> dict:
    with open(path, 'r') as file:
        return yaml.safe_load(file)
