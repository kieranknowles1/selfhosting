# Cron related utility functions

# Describe the cron expression in a human-readable format
export def "cron describe" [
    expression: string
] {
    cronstrue $expression | str trim --char "\n"
}
