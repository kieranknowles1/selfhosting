#!/bin/python3

# TODO: Implement

# # Generate the nginx configuration for the services
# def generate_config []: {
#     $env.GLOBAL_DOMAINS | from yaml | each {|it| $"
#     # ($it.name), ($it.domain).($env.DOMAIN_NAME) -> ($env.LOCAL_IP):($it.port)
#     server {
#         include /etc/nginx/includes/global.conf;
#         server_name ($it.domain).($env.DOMAIN_NAME) ($it.domain).home.arpa;

#         location / {
#             proxy_pass http://($env.LOCAL_IP):($it.port)/;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto $scheme;
#             proxy_set_header Upgrade $http_upgrade;
#             proxy_set_header Connection \"Upgrade\";
#         }
#     }
# "} | str join}

# return ({
#     NGINX_CONFIG: (generate_config)
# } | to yaml)
