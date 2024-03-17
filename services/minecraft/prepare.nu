use ../../utils/log.nu "log info"

# Pack datapacks into zip files for use by the server
def pack_datapacks [] {
    cd datapacks
    ls | where type == "dir" | get name | each {|it|
        log info $"Zipping ($it)"
        # We need to change to the directory to make sure pack.mcmeta and data are in the root of the zip, not in a subdirectory named after the pack
        cd $it
        ^zip --filesync --recurse-paths $"../($it).zip" .
    }
}

pack_datapacks

exit
