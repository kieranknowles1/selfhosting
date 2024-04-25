#!/usr/bin/env python3
# Backup script for self-hosted runner
# Pauses containers, runs Restic, and resumes containers
# WARN: If a backup fails, containers will not be resumed. A server reboot is recommended in this case
# Should be run as root

from os import chdir, path
from subprocess import run
from datetime import datetime

from stages.environment import get_env, stringify_dict
from utils import service

def pause(service: str, env: dict[str, str]):
    print(f"Pausing {service}")
    run(["docker-compose", "--file", f"services/{service}/docker-compose.yml", "pause"], env=env, check=True)

def unpause(service: str, env: dict[str, str]):
    print(f"Unpausing {service}")
    run(["docker-compose", "--file", f"services/{service}/docker-compose.yml", "unpause"], env=env, check=True)

def create_backup(repo: str, password: str, source: str):
    print(f"Starting backup of {source} to {repo}")
    run(["restic", "backup", source], env={
        "RESTIC_REPOSITORY": repo,
        "RESTIC_PASSWORD": password
    }, check=True)

def main():

    script_dir = path.dirname(__file__)
    print(f"chdir to {script_dir}")
    chdir(script_dir)

    env = stringify_dict(get_env())

    start = datetime.now()
    print("=========================")
    print(" --- Starting backup --- ")
    print(f"Backup started at {start}")
    print("=========================")

    to_pause: list[str] = []
    for s in service.list():
        spec = service.load_spec(f"services/{s}/service.yml")
        if spec and 'usesData' in spec and spec['usesData']:
            to_pause.append(s)

    print("Containers going PAUSED for backup")
    for s in to_pause:
        pause(s, env)

    create_backup(env["RESTIC_REPO"], env["RESTIC_PASSWORD"], env["DATA_ROOT"])
    create_backup(env["RESTIC_REMOTE_REPO"], env["RESTIC_PASSWORD"], env["DATA_ROOT"])

    print("Containers going UNPAUSED after backup")
    for s in to_pause:
        unpause(s, env)

    time_taken = datetime.now() - start
    print(f"Backup complete at {datetime.now()}. Took {time_taken}")

if __name__ == '__main__':
    main()
