#!/bin/python3

import docker
from os import environ
import sqlite3

def hash_password(password: str) -> str:
    """Hash a password using PHP's default algorithm. WARN: Input is not sanitized! DO NOT USE ON A PUBLIC API!"""

    with docker.from_env() as client:
        container = client.containers.run(
            "php:7.4-cli",
            f"php -r 'echo password_hash(\"{password}\", PASSWORD_DEFAULT);'",
            remove=True
        )
        return container.decode("utf-8").strip()


def configure():
    print("Configuring speedtest")

    db_path = f"{environ['DATA_ROOT']}/speedtest/database.sqlite"
    password_hash = hash_password(environ['ADGUARD_PASSWORD'])

    with sqlite3.connect(db_path) as conn:
        cursor = conn.cursor()
        # Run every 15 minutes
        cursor.execute(
            "UPDATE settings SET payload = ? WHERE name = 'speedtest_schedule'",
            (environ['SPEEDTEST_SCHEDULE'])
        )

        # Prune old data
        cursor.execute(
            "UPDATE settings SET payload = ? WHERE name = 'prune_results_older_than'",
            (environ['SPEEDTEST_RETENTION'])
        )

        # Secure the admin account
        cursor.execute(
            "UPDATE users SET email = ?, password = ? WHERE name = 'Admin'",
            (environ['OWNER_EMAIL'], environ['ADGUARD_PASSWORD'])
        )
        # TODO: The schedule never gets applied. Probably need to manually add the cron job. Have a look at source code

def main():
    configure()

if __name__ == "__main__":
    main()
