# Self-hosted web services

- [Self-hosted web services](#self-hosted-web-services)
  - [Introduction](#introduction)
  - [Setup](#setup)
    - [Configuration](#configuration)
      - [Paths](#paths)
      - [Ports](#ports)
      - [Time zone](#time-zone)
      - [Secrets](#secrets)
    - [Install](#install)
  - [Post setup](#post-setup)
    - [Cron jobs](#cron-jobs)
    - [API Keys](#api-keys)
    - [Backups](#backups)
    - [Certificate Renewal](#certificate-renewal)

## Introduction
This repository is, first and foremost, a personal project. I am sharing it to help others who may be
interested in self-hosting their own web services, but I will not be providing any support for it.
Breaking changes may be introduced at any time without warning or migration instructions.

Use this at your own risk. I highly recommend using this as a reference and not as a copy-paste solution.

Only ARM architectures, such as the Raspberry Pi, are supported. My deployment is on a Raspberry Pi 5 with
8GB of RAM and a 64-bit OS.

## Setup

### Configuration
Configuration is done through environment variables in `.env` and `.env.user`. `.env`, which is, by default,
configured for my personal setup and should be modified to suit your needs. Namely, you should change the
`DATA_ROOT` and `BACKUP_REPO` variables to point to appropriate locations for your setup.

#### Paths
Paths are configured in `.env` through the `DATA_ROOT` variable. This is set to `/mnt/extern/containers/data` and is
used to store runtime data that should persist at the host level and be backed up. This includes databases
and user data.

#### Ports
Ports are configured in `.env`. Each service has an assigned port in the 8xxx range which can be changed
if needed. Should you need to change these, you will need to re-run `setup.sh` with the `--update` flag

By default, container data is stored in `./data`. This can be changed by modifying the `DATA_ROOT` variable.

Each container has a port defined in `.env` in the 8xxx range. Should you need to change these, you will need to
re-run `setup.sh` with the `--update` flag to apply the changes. No service data will be lost and ports will be
automatically inferred from the `.env` file.

#### Time zone
The time zone is configured in `.env` through the `TIME_ZONE` and is set to `Europe/London` by default.

#### Secrets
The following environment variables must be defined in `.env.user`:
```bash
# The domain name of the server. This must be pointing to the server's IP address.
# IP addresses are NOT supported.
export DOMAIN_NAME=example.com
export LOCAL_IP=192.168.0.123
# Your personal email address. This is used for Let's Encrypt services that require an email address.
export OWNER_EMAIL=mail@example.com

# Paths and keys for Borg
export BORG_PASSPHRASE=something_secure
# You must also generate a SSH key pair with ssh-keygen and add the public key to the BorgBase repository.
# See https://docs.borgbase.com/faq/#all-connections-to-a-borgbase-repo-fail-with-an-error-immediately
# if you are having issues connecting to the repository.
# NOTE: You will not be able to get a shell on a BorgBase repository. This is normal.
export BORGBASE_URL=ssh://something@something.reop.borgbase.com/./repo

# Passwords for the databases. Use a password generator for these.
# Make sure to use a different password for each service.
export FIREFLY_DB_PASSWORD=something_secure
export IMMICH_DB_PASSWORD=something_secure
export JOPLIN_DB_PASSWORD=something_secure

# This must be exactly 32 characters long and url-safe (i.e., [a-zA-Z0-9_-] only)])
export FIREFLY_STATIC_CRON_TOKEN=Exactly32UrlSafeCharactersPlease
```


### Install
Once the secrets are defined, simply run the setup script to install the dependencies
and start everything up:
```bash
sudo ./setup.sh
```

## Post setup

### Cron jobs
The following cron jobs are required to maintain the services. These are not installed automatically.
```bash
# Backup every night
0 0 * * * /path/to/backup.sh
# Renew certificates every two months
0 0 1 */2 * /path/to/renew.sh
```

### API Keys
After setting up and configuring containers, you can add API keys to enable widgets on the dashboard
to `.env.user`. Re-run `setup.sh` with the `--update` flag to apply the changes.
```bash
export IMMICH_API_KEY=1234567890abcdef
export PAPERLESS_API_KEY=1234567890abcdef
```

### Backups
Backups are done using [Borg](https://borgbackup.readthedocs.io/en/stable/). The backup script is
located in `./backup.sh`. It is recommended to run this script on a cron job to ensure regular backups.
Note that containers will be paused during the backup to ensure data consistency.

The backup repository is located in `/mnt/extern/containers/backup` by default and is encrypted using
your Borg and a key written to `.borg-key` during setup. You **must** back up all of:
- The `.borg-key` file
- The `.env.user` file
- The backup repository (at `BACKUP_REPO` in `.env`)

The following data is intentionally excluded from the backup:
- Jellyfin media

### Certificate Renewal
The certificates issued by Let's Encrypt are valid for 90 days. To renew them, simply run the included
`renew.sh` script. You will receive an email notification when the certificates are due to expire.
