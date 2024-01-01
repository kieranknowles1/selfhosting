# Self-hosted web services

## Setup

### Secrets
The following environment variables must be defined in `.env.user`:
```bash
# The domain name of the server
export DOMAIN_NAME=example.com
export LOCAL_IP=192.168.0.123

export IMMICH_DB_PASSWORD=something_secure
```

### Install
Once the secrets are defined, simply run the setup script to install the dependencies
and start everything up:
```bash
sudo ./setup.sh
```

## Post setup

### API Keys
After setting up and configuring containers, you can add API keys to enable widgets on the dashboard
to `.env.user`. Re-run `setup.sh` with the `--update` flag to apply the changes.
```bash
IMMICH_API_KEY=1234567890abcdef
```
