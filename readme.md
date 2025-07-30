> [!WARNING]
> This repository is obsolete, issues will not be fixed. A subset of features will be moved to
> my [nixcfg](https://github.com/kieranknowles1/nixcfg) repo.

# Self-hosted Web Services
- [Self-hosted Web Services](#self-hosted-web-services)
  - [Introduction](#introduction)
    - [Guiding Principles](#guiding-principles)
  - [Setup](#setup)
    - [Configuration](#configuration)
    - [Serving Static Files](#serving-static-files)
    - [Install](#install)
  - [Post setup](#post-setup)
    - [Service Configuration](#service-configuration)
      - [API Keys](#api-keys)
    - [Backups](#backups)
    - [VPN](#vpn)
  - [Included Services](#included-services)
  - [Development Information](#development-information)

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
4. **Automated**: I believe that manual processes are error-prone and time-consuming. As such, I have automated
   as much as possible. This includes the setup of the services, the renewal of certificates, and the backup
   process. I hope that by doing this I can make it easier to maintain the services in the long run as
   you can create a replicable environment with minimal effort. That being said, some services are more
   difficult to automate than others and require manual intervention as discussed in [Post setup](#post-setup).

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

<!-- TODO: Backups are taking a while so I'd like to implement the change soon. -->
You will more than likely need to change the paths in `environment.yml` to suit your setup.
I recommend using a separate drive formatted as btrfs for forward compatibility once [#5](https://github.com/kieranknowles1/selfhosting/issues/5) is implemented.
Or not, I haven't done any research into whether it suits my needs yet. I'll update this once it's clear what path I want to take.

Where possible, services are statically configured in such a way that all configs are in this repository
(see [The Unreasonable Effectiveness of Plain Text](https://www.youtube.com/watch?v=WgV6M1LyfNY), not my words, but I agree with them).

### Serving Static Files
Files in `${DATA_ROOT}/nginx/static` will be served at `https://${DOMAIN}/static/`. This is primarialy used
to host a resource pack for Minecraft, but can be used for anything you like. Please be mindful that there is
no authentication on this directory, so don't put anything sensitive in there.

### Install
Once your secrets are defined, you can install the Nushell terminal and run the setup script
to start everything up.
```bash
sudo apt-get update
sudo apt-get install -y npm # Npm is the easiest way to install Nushell
sudo npm install -g nushell
./setup.nu
```

## Post setup

### Service Configuration
On initial setup, you will notice a number of errors on the dashboard. This is because the services are not
fully configured yet.

#### API Keys
Several services require API keys to function. These should be added to `userenv.yml` as per the schema and
`setup.nu` should be run with the `--update` flag to apply the changes.

### Backups
Backups are done using [Restic](https://restic.net/). The `./backup.nu` script will back up the data to the
repositories you have configured. The setup script will configure a cron job to run this script nightly as root.

Note that containers will be paused during the backup to ensure data consistency. Therefore, you will not be able
to access the services during the backup.

You MUST keep the password for the repository safe, you will not be able to restore without it.

The following data is intentionally excluded from the backup:
- Jellyfin media

### VPN
The [WireGuard](https://www.wireguard.com/) VPN is configured to run on port 51820, which you will need
to forward on your router.

A peer will be configured for each device in `userenv.yml`, QR codes for which are found in
`${DATA_ROOT}/wireguard/peer_${CLIENT_NAME}/peer_${CLIENT_NAME}.png`.

If you're feeling fancy, you can use `docker logs wireguard` to print these to the terminal and scan them.

## Included Services
The following services are included in this repository. In addition I feel some deserve special attention
and are marked with a ⭐ along with a brief explanation of why I believe they stand out from the crowd.

- [Adguard](https://adguard.com/) - DNS and ad blocking
- [Firefly III](https://firefly-iii.org/) - Personal finance
- [Gatus](https://gatus.io) - Service monitoring
- [Forgejo](https://forgejo.org/) - Git server
- [Immich](https://immich.app/) ⭐ - Photo Library<br>
  I was simply blown away by the quality of Immich's smart search. It's an amazing way to find exactly the
  photo you're thinking of and far surpasses the competition, even the big proprietary players.
  This is a shining example of how open source incentivises innovation rather than lock-in. Seaching
  for "kittens cuddling" will return exactly that ([cat tax](media/kittens.jpg), the tabby is called Millie
  and the tuxedo is called Cookie, they were 6 weeks old at the time of the photo in 2015 and I love them both to bits.), all of the other services I tried would return nothing at all.
- [Jellyfin](https://jellyfin.org/) - Media server
- [Joplin](https://joplinapp.org/) - Note taking
- [Itzg Minecraft](https://github.com/itzg/docker-minecraft-server) - Minecraft server
- [Nginx](https://www.nginx.com/) - Reverse proxy
- [OpenSpeedTest](https://openspeedtest.com/) - Speed test
- [Paperless NGX](https://github.com/paperless-ngx/paperless-ngx) - Document management
- [Tilde](https://github.com/xvvvyz/tilde) - Minimal home page. No container, just a static site served by Nginx.
  - I use a forked version named [extern-tilde](https://github.com/kieranknowles1/extern-tilde) which uses
    an external config file for easier automation, and supports icons for the links.
- [WireGuard](https://www.wireguard.com/) - VPN
- [What's Up Docker](https://github.com/fmartinou/whats-up-docker) - Container Update Checker

## Development Information
Further documentation can be found in the [docs](docs/index.md) directory.
