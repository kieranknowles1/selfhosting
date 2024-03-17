# Run an external script and capture its stdout
# Throw if the script fails
export def "script run" [
    path: string
] nothing -> string {
    let result = do {
        nu $path
    } | complete

    return (match $result.exit_code {
        0 => $result.stdout
        _ => {
            print $result.stdout
            print $result.stderr
            error make {
                msg: $"Script failed with code ($result.exit_code)",
                code: $result.exit_code,
                stdout: $result.stdout,
                stderr: $result.stderr
            }
        }
    })
}
