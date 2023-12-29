# Self-hosted web services

## Setup

### Secrets
The following environment variables must be defined in `.env.user`:
```bash
# The domain name of the server
export DOMAIN_NAME=example.com
```

### Install
Once the secrets are defined, simply run the setup script as root to install the dependencies
and start everything up:
```bash
sudo ./setup.sh
```
