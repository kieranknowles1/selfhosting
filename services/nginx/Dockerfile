FROM nginxinc/nginx-unprivileged:alpine

COPY --chown=nginx:nginx ./nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx ./includes /etc/nginx/includes

#COPY --chown=nginx:nginx ./tilde/index.html /var/www/tilde/index.html
#COPY --chown=nginx:nginx ./commands.generated.json /var/www/tilde/commands.json
