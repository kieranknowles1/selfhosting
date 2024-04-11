# Service Specification
Each subdirectory of `services`, at a minimum, contains a `service.yml` and a `docker-compose.yml` file.

See [service.schema.yml](../schemas/service.schema.yml) for the schema of `service.yml`.

## Scripts
A service can have one or more scripts defined in `service.yml` to be executed during the setup process.
These have access to the environment variables defined in `environment.yml` and `userenv.yml`.

Additionally, global information about all services is available in the `/tmp/self-hosted-setup/` directory.
- `combined-specs.yml`: A YAML object, where each key is the name of a service and the value is the service's `service.yml`.
  - See [service.schema.yml](../schemas/service.schema.yml) for the schema of each value.

## Template Files
Files with the `.template` extension are preprocessed during setup to replace variables with their values
through the Bash syntax `${VARIABLE}`. Theses files are then moved to their final location without the `.template`
extension.

The output of this process is not tracked by git, each file must be manually added to `.gitignore` to prevent
it from being committed.

## Order of Execution

Scripts for a service are executed in the following order:
- `prepare`: Used for any pre-deployment setup such as [packing files](../services/minecraft/prepare.nu).
  Stdout will be logged during deployment.
- `configure`: Used to generate environment variables such as [hashed passwords](../services/adguard/configure.nu)
  that will be available to ALL later steps. Stdout MUST be a valid YAML object and WILL NOT be logged.
- **Replace Template Variables**: See [Template Files](#template-files)
- **Deploy Docker Compose**
- `afterDeploy`: Used for any post-deployment setup such as [running queries on the database](../services/speedtest/after-deploy.nu)
  Stdout will be logged during deployment.
