#!/usr/bin/env python3

from os import environ
import sqlite3

def hash_password(password: str) -> str:
    # TODO: Hash for PHP
    return password


def configure():
    print("Configuring speedtest")

    # TODO: Database is owned as root. Can't currently access it
    return

    db_path = f"{environ['DATA_ROOT']}/speedtest/database.sqlite"
    password_hash = hash_password(environ['ADGUARD_PASSWORD'])

    with sqlite3.connect(db_path) as conn:
        cursor = conn.cursor()
        # Run every 15 minutes
        cursor.execute(
            "UPDATE settings SET payload = ? WHERE name = 'speedtest_schedule'",
            (environ['SPEEDTEST_SCHEDULE'],)
        )

        # Prune old data
        cursor.execute(
            "UPDATE settings SET payload = ? WHERE name = 'prune_results_older_than'",
            (environ['SPEEDTEST_RETENTION'],)
        )

        # Secure the admin account
        cursor.execute(
            "UPDATE users SET email = ?, password = ? WHERE name = 'Admin'",
            (environ['OWNER_EMAIL'], password_hash,)
        )
        # TODO: The schedule never gets applied. Probably need to manually add the cron job. Have a look at source code

def main():
    configure()

if __name__ == "__main__":
    main()
