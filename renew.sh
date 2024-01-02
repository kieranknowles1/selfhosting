source .env
source .env.user
docker-compose -f ./services/nginx/docker-compose.yml \
  run --rm certbot renew
