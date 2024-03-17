# Run an external script and capture its stdout
# Throw if the script fails
export def "script run" [
    path: string
] nothing -> string {
    let result = do {
        nu $path
    } | complete

    match $result.exit_code {
        0 => $result.stdout
        _ => { error make {
            msg: "Script failed",
            code: $result.exit_code,
            stdout: $result.stdout,
            stderr: $result.stderr
        } }
    }
}
