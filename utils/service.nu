# List all services in the ./services directory
export def "service list" [] nothing -> list<string> {
    ls ($env.FILE_PWD + /services/*/docker-compose.yml) | get name | parse ($env.FILE_PWD + "/services/{name}/docker-compose.yml") | get name
}
