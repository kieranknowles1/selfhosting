# Self-hosted web services

## Setup

### Secrets
The following environment variables must be defined in `.env.user`:
```bash
# The domain name of the server
export DOMAIN_NAME=example.com
export LOCAL_IP=192.168.0.123
```

### Install
Once the secrets are defined, simply run the setup script as root to install the dependencies
and start everything up:
```bash
sudo ./setup.sh
```
