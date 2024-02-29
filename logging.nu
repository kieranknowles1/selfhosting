# Log an error message to the console
export def "log error" [message: string] {
    print --stderr $"[(ansi red_bold)ERROR(ansi reset)] ($message)"
}

# Log a warning message to the console
export def "log warn" [message: string] {
    print $"[(ansi yellow_bold)WARN(ansi reset)] ($message)"
}

# Log a debug message to the console
export def "log info" [message: string] {
    print $"[(ansi blue_bold)INFO(ansi reset)] ($message)"
}
