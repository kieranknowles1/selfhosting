#!/bin/bash
# Generate the cron jobs for the system
# Must be run from the root of the project

echo "# Auto-generated cron jobs for the containers"
echo "# Add this to your crontab with crontab -e"
echo "# Backup every night at 1am"
echo "0 1 * * * ${PWD}/backup.sh"
echo "# Renew SSL certificates every 2 months"
echo "0 0 1 */2 * ${PWD}/renew.sh"
