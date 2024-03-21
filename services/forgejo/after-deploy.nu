# Take ownership of all files
let user = id -u -n
let group = id -g -n

sudo chown -R $"($user):($group)" $"($env.DATA_ROOT)/forgejo"

# Create an empty database for the app
sqlite3 $"($env.DATA_ROOT)/forgejo/forgedb.db" ""
