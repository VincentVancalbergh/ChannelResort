$wowAddonFolder = "C:\Games\World of Warcraft\_classic_\Interface\AddOns\ChannelResort"
if (Test-Path -Path $wowAddonFolder) {
    #Delete files first
    $Items = Get-ChildItem -LiteralPath $wowAddonFolder -Recurse -Force
    foreach ($Item in $Items) {
        if ($Item.PSIsContainer -eq $false) {
            $Item.Delete()
        }
    }
    #Then delete folders
    $Items = Get-ChildItem -LiteralPath $wowAddonFolder -Recurse -Force
    foreach ($Item in $Items) {
        $Item.Delete()
    }
}
else {
    New-Item -Path $wowAddonFolder -ItemType Directory
}
Copy-Item -Path "..\ChannelResort\*" -Destination $wowAddonFolder -Recurse