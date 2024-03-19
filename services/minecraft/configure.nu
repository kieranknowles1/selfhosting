# Get the download URL for a mod from Modrinth of a specific Minecraft version
def modrinth_download_url [
    idOrSlug: string
    minecraftVersion: string
]: nothing -> string {
    let url = $"https://api.modrinth.com/v2/project/($idOrSlug)/version?game_versions=[\"($minecraftVersion)\"]&loaders=[\"fabric\"]"

    let response = http get $url
    # NOTE: This assumes the API returns the latest version first
    let files = $response.0.files

    return ($files | get url | str join "\n")
}

# Generate download links for the mods used.
def generate_mods [
    version: string
]: nothing -> string {[
    (modrinth_download_url fabric-api $version)
    (modrinth_download_url lithium $version)
    (modrinth_download_url bluemap $version)
] | str join "\n"}

let version = $env.MINECRAFT_VERSION

return ({
    MINECRAFT_MODS: (generate_mods $version)
} | to yaml)
