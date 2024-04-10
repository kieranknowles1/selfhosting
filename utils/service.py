"""Type definitions for service.yml files"""

from __future__ import annotations

from typing import TypedDict, NotRequired, Optional
import yaml

def load_spec(path: str) -> Optional[Service]:
    '''
    Load a service schema from a file

    Throws if the file is not found, but an empty file is considered valid
    '''
    with open(path) as file:
        return yaml.safe_load(file)

class Service(TypedDict):
    domains: NotRequired[list[Domain]]
    uses: NotRequired[list[str]]
    scripts: NotRequired[Scripts]

class Domain(TypedDict):
    domain: str
    name: str
    portVar: str
    includeInStatus: NotRequired[bool]

class Scripts(TypedDict):
    prepare: NotRequired[str]
    configure: NotRequired[str]
    afterDeploy: NotRequired[str]
