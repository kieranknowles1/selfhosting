use ../../utils/cron.nu "cron describe"

return ({
    SPEEDTEST_SCHEDULE_HUMAN: (cron describe $env.SPEEDTEST_SCHEDULE | str downcase),
} | to yaml)
