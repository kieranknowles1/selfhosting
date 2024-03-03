# Get a list of services to deploy, along with their configuration
export def get_services [
    config: record
]: nothing -> list<record<name: string, port: int, health_endpoint: string, backup_pause: bool>> {
    return [{
        name: 'Chef',
        domain: 'chef',
        port: $config.CHEF_WEB_PORT,
    }, {
        name: 'Chef API',
        domain: 'chefapi',
        port: $config.CHEF_BACKEND_PORT,
        health_endpoint: '/api/v1/recipe/1',
    }, {
        name: 'CyberChef',
        domain: 'cyberchef',
        port: $config.CYBERCHEF_PORT,
        directory: 'cyberchef',
    }, {
        name: 'Firefly III Importer',
        domain: 'firefly-importer',
        port: $config.FIREFLY_IMPORTER_PORT,
        # Same compose as the main Firefly III app, no need to pause it separately
        # directory: 'firefly',
        # backup_pause: true,
    }, {
        name: 'Firefly III',
        domain: 'firefly',
        port: $config.FIREFLY_APP_PORT,
        directory: 'firefly',
        backup_pause: true,
    }, {
        name: 'Gatus',
        domain: 'gatus',
        port: $config.GATUS_PORT,
    }, {
        name: 'Gitea',
        domain: 'gitea',
        port: $config.GITEA_WEB_PORT,
        directory: 'gitea',
        backup_pause: true,
    }, {
        name: 'Glances',
        domain: 'glances',
        port: $config.GLANCES_PORT,
    }, {
        name: 'Immich',
        domain: 'immich',
        port: $config.IMMICH_PORT,
        directory: 'immich',
        backup_pause: true,
    }, {
        name: 'Jellyfin',
        domain: 'jellyfin',
        port: $config.JELLYFIN_PORT,
    }, {
        name: 'Joplin',
        domain: 'joplin',
        port: $config.JOPLIN_PORT,
        directory: 'joplin',
        backup_pause: true,
    }, {
        name: 'Minecraft',
        port: $config.MINECRAFT_PORT,
        directory: 'minecraft',
        backup_pause: true,
    }, {
        name: 'Paperless',
        domain: 'paperless',
        port: $config.PAPERLESS_PORT,
        directory: 'paperlessngx',
        backup_pause: true,
    }, {
        name: 'Speedtest',
        domain: 'speedtest',
        port: $config.SPEEDTEST_PORT,
        directory: 'speedtest',
    }, {
        name: `What's Up Docker`,
        domain: 'wud',
        port: $config.WUD_PORT,
        directory: 'wud',
        backup_pause: true,
    }]
}
