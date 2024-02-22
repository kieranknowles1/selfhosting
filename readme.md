# Self-hosted web services
- [Self-hosted web services](#self-hosted-web-services)
  - [Introduction](#introduction)
  - [Setup](#setup)
    - [Configuration](#configuration)
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
Default config is provided in `environment.yml` and `userenv.yml`. The former is used to configure non-sensitive
data in the repository, such as paths and ports, and the latter is used to configure sensitive data, such as
passwords and API keys.

`userenv.yml` should be filled in according to the schema in `userenv.schema.yml` before running the setup script.
Should a variable appear in both, the value in `userenv.yml` will take precedence.

API keys in the schema are optional, but some widgets on the dashboard will not work without them.

Most of the values in `environment.yml` will work out of the box, but you will likely need to change the
paths to suit your setup.

Most variables are safe to change after the setup is complete, except for passwords. Changing a path will
require you to move the data manually. To apply changes, run `setup.nu` with the `--update` flag.

### Install
Once the secrets are defined, simply run the setup script to install the dependencies
and start everything up:
```bash
sudo ./setup.sh
```

## Post setup

### Cron jobs
Cron jobs are used to perform regular maintenance tasks, such as backups and certificate renewal.

The recommended cron jobs can be generated using `gencron.sh` and added using `crontab -e`.

### API Keys
After configuring the containers, you will need to add API keys to `userenv.yml` and run `setup.nu --update`.
See the schema for the required keys.

### Backups
Backups are done using [Restic](https://restic.net/). The backup script is located in `./backup.nu` and should
be run, as root, by a cron job on a regular basis. I recommend running it nightly.

Note that containers will be paused during the backup to ensure data consistency. Therefore, you will not be able
to access the services during the backup.

You MUST keep the password for the repository safe, you will not be able to restore without it.

The following data is intentionally excluded from the backup:
- Jellyfin media

### Certificate Renewal
The certificates issued by Let's Encrypt are valid for 90 days. To renew them, simply run the included
`renew.sh` script. You will receive an email notification when the certificates are due to expire.
