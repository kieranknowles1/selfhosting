# Get a list of services to deploy, along with their configuration
export def get_services [
    config: record
]: nothing -> list<record<name: string, domain: string, port: int, healthcheck: string, backuppause: bool>> {
    return [{
        name: 'Chef',
        domain: 'chef',
        port: $config.CHEF_WEB_PORT,
    }, {
        name: 'Chef API',
        domain: 'chefapi',
        port: $config.CHEF_BACKEND_PORT,
        healthcheck: '/api/v1/recipe/1',
    }, {
        name: 'Firefly III Importer',
        domain: 'firefly-importer',
        port: $config.FIREFLY_IMPORTER_PORT,
    }, {
        name: 'Firefly III',
        domain: 'firefly',
        port: $config.FIREFLY_APP_PORT,
    }, {
        name: 'Gatus',
        domain: 'gatus',
        port: $config.GATUS_PORT,
    }, {
        name: 'Gitea',
        domain: 'gitea',
        port: $config.GITEA_WEB_PORT,
    }, {
        name: 'Glances',
        domain: 'glances',
        port: $config.GLANCES_PORT,
    }, {
        name: 'Immich',
        domain: 'immich',
        port: $config.IMMICH_PORT,
    }, {
        name: 'Jellyfin',
        domain: 'jellyfin',
        port: $config.JELLYFIN_PORT,
    }, {
        name: 'Joplin',
        domain: 'joplin',
        port: $config.JOPLIN_PORT,
    }, {
        name: 'Paperless',
        domain: 'paperless',
        port: $config.PAPERLESS_PORT,
    }, {
        name: `What's Up Docker`,
        domain: 'wud',
        port: $config.WUD_PORT,
    }]
}
