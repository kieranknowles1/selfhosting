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

def create_backup(repo: str, password: str, source: str, env: dict[str, str]):
    print(f"Starting backup of {source} to {repo}")
    full_env = env | {
        "RESTIC_REPOSITORY": repo,
        "RESTIC_PASSWORD": password,
    }
    run(["restic", "backup", source], env=full_env, check=True)

def prepare_script():
    """
    Do pre-backup setup, such as changing directory and setting environment variables.
    Returns the environment dict.
    """
    script_dir = path.dirname(__file__)
    print(f"chdir to {script_dir}")
    chdir(script_dir)

    env = stringify_dict(get_env())
    # We run this as root, so let Restic use root's cache dir
    env["XDG_CACHE_HOME"] = "/root/.cache"
    return env

def pause_all(env: dict[str, str]):
    """
    Pause all services that use the data directory.

    Returns a list of services that were paused.
    """
    to_pause: list[str] = []
    for s in service.list():
        spec = service.load_spec(f"services/{s}/service.yml")
        if spec and 'usesData' in spec and spec['usesData']:
            to_pause.append(s)

    print("Containers going PAUSED for backup")
    for s in to_pause:
        pause(s, env)

    return to_pause

def unpause_all(services: list[str], env: dict[str, str]):
    """
    Unpause all services that were paused.

    Takes a list of services that were paused.
    """
    print("Containers going UNPAUSED after backup")
    for s in services:
        unpause(s, env)

CLEAN_POLICY = [
    "--keep-daily", "7", # Keep daily backups of the last week
    "--keep-weekly", "52", # Keep weekly backups of the last year
    "--keep-monthly", "10000", # Keep monthly backups practically forever
]

def clean(repo: str, password: str, env: dict[str, str]):
    print(f"Cleaning up old backups in {repo}")

    full_env = env | {
        "RESTIC_REPOSITORY": repo,
        "RESTIC_PASSWORD": password,
    }

    # Delete snapshots according to our policy
    run(["restic", "forget", *CLEAN_POLICY], env=full_env, check=True)
    # Delete unused data
    run(["restic", "prune"], env=full_env, check=True)

def main():
    env = prepare_script()

    start = datetime.now()
    print("=========================")
    print(" --- Starting backup --- ")
    print(f"Backup started at {start}")
    print("=========================")

    paused = pause_all(env)

    create_backup(env["RESTIC_REPO"], env["RESTIC_PASSWORD"], env["DATA_ROOT"], env)
    create_backup(env["RESTIC_REMOTE_REPO"], env["RESTIC_PASSWORD"], env["DATA_ROOT"], env)

    unpause_all(paused, env)

    print("=========================")
    print(" --- Cleaning old backups --- ")
    print("=========================")

    # Clean up old backups
    # This is kept separate as it doesn't need services to be paused, so we can resume service
    # before cleaning
    clean(env["RESTIC_REPO"], env["RESTIC_PASSWORD"], env)
    clean(env["RESTIC_REMOTE_REPO"], env["RESTIC_PASSWORD"], env)

    time_taken = datetime.now() - start
    print(f"Backup complete at {datetime.now()}. Took {time_taken}")

if __name__ == '__main__':
    main()
