# Log an error message to the console
export def "log error" [message: string] {
    print $"[(ansi red_bold)ERROR(ansi reset)] ($message)"
}

# Log a debug message to the console
export def "log info" [message: string] {
    print $"[(ansi blue_bold)INFO(ansi reset)] ($message)"
}
