# Self-hosted Web Services
- [Self-hosted Web Services](#self-hosted-web-services)
  - [Introduction](#introduction)
    - [Guiding Principles](#guiding-principles)
  - [Setup](#setup)
    - [Configuration](#configuration)
    - [Install](#install)
  - [Post setup](#post-setup)
    - [Cron Jobs](#cron-jobs)
    - [Service Configuration](#service-configuration)
      - [Speedtest](#speedtest)
      - [API Keys](#api-keys)
    - [Backups](#backups)
    - [Certificate Renewal](#certificate-renewal)

## Introduction
This repository is, first and foremost, a personal project. I am sharing it to help others who may be
interested in self-hosting their own web services, but I will not be providing any support for it.
Breaking changes may be introduced at any time without warning or migration instructions.

Use this at your own risk. I highly recommend using this as a reference and not as a copy-paste solution.
If you do decide to use it, I suggest you fork the repository and carefully review any changes before
pulling them in. (Key words in the commit messages to look out for are `BREAKING` and `migration`. I
will link to any relevant documentation but will not provide scripts to automate any migrations.)

Only ARM architectures, such as the Raspberry Pi, are supported. My deployment is on a Raspberry Pi 5 with
8GB of RAM and a 64-bit OS.

### Guiding Principles
The guiding principles of this project are:

1. **Open Source**: All software used is **fully** open source. This means no proprietary software. To the
   best of my knowledge, you can access the source code for every piece of software used in this project.
   I believe that open source software is better for everyone (a greater good if you will) and I want to
   support it as much as possible.
2. **Self-hosted**: As much as possible, these services will work without relying on third-party services.
   If a third-party service is required, it should be replaceable with a self-hosted alternative.
   A good example of this is the use of [Restic](https://restic.net/) for backups, which can back up to
   any cloud storage provider of your choice, or even another server you own. (please make sure to follow the [3-2-1 backup rule](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/))
3. **Privacy**: I believe that privacy is a fundamental human right. As such, data will remain in your control
   at all times to the best of my ability. This means no tracking, no telemetry, and no backing up without
   local encryption that only you have the key to.

How well I have achieved these principles is up to you to decide. If you have any suggestions for improvement,
please let me know.

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

### Cron Jobs
Cron jobs are used to perform regular maintenance tasks, such as backups and certificate renewal.

The recommended cron jobs can be generated using `gencron.sh` and added using `crontab -e`.

### Service Configuration
On initial setup, you will notice a number of errors on the dashboard. This is because the services are not
fully configured yet.

#### Speedtest
The speed test service does not automatically run tests by default. To enable it, log on using the default
credentials `admin@example.com` and `password` and configure the service. The following changes are recommended:
- General:
  - Speedtest schedule: `*/15 * * * *` (every 15 minutes)
  - Prune results older than: `30` days
- Users -> admin:
  - Change the password
  - Change the email address

#### API Keys
Several services require API keys to function. These should be added to `userenv.yml` as per the schema and
`setup.nu` should be run with the `--update` flag to apply the changes.

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
