# Generate the home page config
def generate_home []: {
    $env.GLOBAL_DOMAINS | from yaml | each {|it| [
        ($it.name | str substring 0..2), # TODO: Shortcut
        {
            name: $it.name,
            url: $"https://($it.domain).($env.DOMAIN_NAME)",
            # TODO: Icon
        }
    ]}
}

generate_home | save tilde.generated.json --force
