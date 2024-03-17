use ../../utils/log.nu "log info"
use ../../utils/php.nu "php hash_password"

# Configure the speedtest container with recommended defaults
# WARN: Credentials MUST come from a trusted source. There are no checks for SQL injection
def configure [] {
    log info "Configuring speedtest"

    let dbPath = $"($env.DATA_ROOT)/speedtest/database.sqlite"
    # TODO: Don't use adguard vars here
    let passwordHash = (php hash_password $env.ADGUARD_PASSWORD)

    let commands = [
        # Run speedtest every 15 minutes
        $"UPDATE settings SET payload = \"($env.SPEEDTEST_SCHEDULE)\" WHERE name = \"speedtest_schedule\""
        # Prune old data
        $"UPDATE settings SET payload = ($env.SPEEDTEST_RETENTION) WHERE name = \"prune_results_older_than\""
        # Secure the admin account
        $"UPDATE users SET email = \"($env.OWNER_EMAIL)\", password = \"($passwordHash)\" WHERE name = \"Admin\""
    ] | str join ";\n"

    # TODO: The schedule never gets applied. Probably need to manually add the cron job. Have a look at source code
    # to see how it's done
    sudo sqlite3 $dbPath $commands
}

configure

exit
