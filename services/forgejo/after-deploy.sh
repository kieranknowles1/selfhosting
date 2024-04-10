#!/bin/bash

# Take ownership of all files
user=$(id -u -n)
group=$(id -g -n)

sudo chown -R "$user:$group" "$DATA_ROOT/forgejo"

# Create an empty database for the app to use
sqlite3 "($DATA_ROOT)/forgejo/forgedb.db" ""

exit 0
