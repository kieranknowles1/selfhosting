from typing import Any, Optional, Literal, overload
from logging import getLogger
from subprocess import run
import os
import yaml

import utils.service as service

logger = getLogger(__name__)

@overload
def run_stage(
    stage: Literal["prepare", "afterDeploy"],
    spec: Optional[service.Service],
    env: dict[str, str]
) -> None:
    ...

@overload
def run_stage(
    stage: Literal["configure"],
    spec: Optional[service.Service],
    env: dict[str, str]
) -> Optional[dict[str, Any]]:
    ...

def run_stage(stage: str, spec: Optional[service.Service], env: dict[str, str], is_update: bool):
    if not spec or not "scripts" in spec:
        return
    script = spec["scripts"].get(stage)
    if script is None:
        return

    env = env.copy()
    # Bash is weird, it doesn't support booleans so we have to use the lack of a variable to represent false
    if is_update:
        env["IS_UPDATE"] = "true"

    logger.info(f"Running {stage} script {script}")
    result = run(
        f"./{script}",
        check=True,
        capture_output=stage == "configure",
        env=env,
    )
    if stage == "configure":
        return yaml.safe_load(result.stdout)

def replace_templates(dir: str, env: dict[str, str]):
    '''Replace all templates in the directory and its subdirectories with the environment variables, uses bash ${} syntax'''

    logger.info(f"Replacing templates in {dir}")

    for root, _, files in os.walk(dir):
        for file in files:
            if not file.endswith(".template"):
                continue

            logger.info(f"Replacing templates in {root}/{file}")

            with open(f"{root}/{file}") as template:
                template = template.read()
                for key, value in env.items():
                    template = template.replace(f"${{{key}}}", value)

            with open(f"{root}/{file[:-len('.template')]}", "w") as output:
                output.write(template)

            # Check for unexpanded variables.
            if "${" in template:
                raise ValueError(f"Unexpanded variables in {root}/{file}. Search output file for '${{'")

def deploy_service(dir: str, env: dict[str, str], is_update: bool):
    '''Deploy a service from the services directory, running any necessary scripts.'''
    env = env.copy()
    logger.info(f"Deploying {dir}")
    spec = service.load_spec(f"services/{dir}/service.yml")

    working_dir = os.getcwd()
    try:
        os.chdir(f"services/{dir}")

        run_stage("prepare", spec, env, is_update)

        config = run_stage("configure", spec, env, is_update)
        if config is not None:
            env.update(config)

        replace_templates(".", env)

        run(
            ["docker-compose", "up", "--build", "--detach", "--remove-orphans"],
            check=True, env=env
        )
        run_stage("afterDeploy", spec, env, is_update)
    finally:
        os.chdir(working_dir)
