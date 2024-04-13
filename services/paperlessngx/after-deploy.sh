#!/bin/bash

if [ ! $IS_UPDATE ]; then
    docker-compose run --rm webserver createsuperuser
fi

