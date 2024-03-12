use "log.nu" "log error"

# List all services in the ./services directory
export def "service list" [] nothing -> list<string> {
    ls ($env.FILE_PWD + /services/*/docker-compose.yml) | get name | parse ($env.FILE_PWD + "/services/{name}/docker-compose.yml") | get name
}

# List subdomains, their service names, and their ports
export def "service subdomains" [
    $environment: record
] nothing -> list<record<domain: string, name: string, port: int, includeInStatus: bool>> {
    service list | each {|it|
        try {
            open $"($env.FILE_PWD)/services/($it)/service.yml"
        } catch {
            log error $"Service ($it) does not have a service.yml file"
            null
        }
    } | filter {|it| $it != null } | get domains | flatten | each {|it| return {
        domain: $it.domain
        name: $it.name
        port: ($environment | get $it.portVar)
        includeInStatus: ($it.includeInStatus? | default true)
    }}
}

# List subdomains that use the data folder
export def "service usingdata" [] nothing -> list<string> {
    service list | where {|it| open $"($env.FILE_PWD)/services/($it)/service.yml" | get usesData? }
}
