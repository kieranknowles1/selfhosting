FROM nginxinc/nginx-unprivileged

COPY --chown=nginx:nginx ./nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx ./includes /etc/nginx/includes

COPY --chown=nginx:nginx ./tilde /var/www/tilde
# TODO: Copy tilde user config
