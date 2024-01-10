# Run from cron, so need to CD here from home directory
cd "$(dirname "$0")"

source .env
source .env.user
docker-compose -f ./services/nginx/docker-compose.yml \
  run --rm certbot renew
