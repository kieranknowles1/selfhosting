# Generate the gatus configuration for the services
# NOTE: This is YAML, so indentation matters
def generate_gatus_config [] {
    $env.GLOBAL_DOMAINS | from yaml | each {|it| $"
  - name: ($it.name)
    group: Services
    url: https://($it.domain).($env.DOMAIN_NAME)($it.health_endpoint? | default "/")
    interval: 5m
    client:
        insecure: true
    conditions:
      - \"[STATUS] == 200\"
      - \"[RESPONSE_TIME] < ($env.HEALTH_TIMEOUT)\"
"} | str join}

return ({
    GATUS_CONFIG: (generate_gatus_config)
} | to yaml)
