use "log.nu" "log error"

# List all services in the ./services directory
export def "service list" [] nothing -> list<string> {
    ls ($env.FILE_PWD + /services/*/service.yml) | get name | parse ($env.FILE_PWD + "/services/{name}/service.yml") | get name
}

# Get the scripts for a service
export def "service scripts" [] string -> record<prepare: string?, configure: string?, afterDeploy: string?> {each {|it|
    open $"($env.FILE_PWD)/services/($it)/service.yml" | get scripts? | default {}
}}

# List subdomains, their service names, and their ports
export def "service subdomains" [
    $environment: record
] nothing -> list<record<domain: string, name: string, port: int, includeInStatus: bool>> {
    service list | each {|it|
        open $"($env.FILE_PWD)/services/($it)/service.yml"
    } | get domains | flatten | each {|it| return {
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
