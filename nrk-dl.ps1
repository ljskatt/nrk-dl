param (
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Name,

    [Parameter()]
    [switch]
    $Drop_subtitles
)

$ProgressPreference = 'SilentlyContinue'
$root_location = Get-Location

if (!(Test-Path -PathType "Leaf" -Path "youtube-dl.exe")) {
    Write-Output "Downloading youtube-dl"
    Invoke-WebRequest "https://youtube-dl.org/downloads/latest/youtube-dl.exe" -OutFile "youtube-dl.exe"
    Write-Output "Downloaded youtube-dl"
}

if (!(Test-Path -PathType "Container" -Path "downloads")) {
    New-Item -ItemType "Directory" -Path "downloads" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads") {
        Write-Output "Opprettet downloads mappe"
    }
    else {
        Write-Output "Kunne ikke opprette downloads mappe"
        exit
    }   
}

$seasons = $null
$standalone = $null
$seasons = (Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/series/$name")._links.seasons.name
if ($seasons){
    $type = "series"
}
else {
    $standalone = (Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/programs/$name")._links.share.href
    if ($standalone){
        $type = "standalone"
    }
    else {
        Write-Output "Kunne ikke finne program/serie"
        exit
    }
}

if (!(Test-Path -PathType "Container" -Path "downloads/$name")) {
    New-Item -ItemType "Directory" -Path "downloads/$name" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads/$name"){
        Write-Output "Opprettet $name mappe"
    }
    else {
        Write-Output "Kunne ikke opprette $name mappe"
        exit
    }
}
Set-Location -Path "downloads/$name"

if ($type -eq "standalone"){
    $standalone = $standalone -replace '{&autoplay,t}', ''
    & "$root_location\youtube-dl.exe" "$standalone"
}

if ($type -eq "series"){
    $episodes = @()
    $subtitles = @()
    foreach ($season in $seasons) {
        $episodes_req = Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/series/$name/seasons/$season"
        

        foreach ($episode_raw in $episodes_req._embedded.episodes) {
            $episodes += New-Object -TypeName "PSObject" -Property @{'url'=$episode_raw._links.share.href;'season'="$season"}

            if (!($Drop_subtitles)) {
                $episode_id = $episode_raw.prfId
                $subs = $null
                $subs = (invoke-restmethod "https://psapi.nrk.no/playback/manifest/program/$episode_id").playable.subtitles
                foreach ($sub in $subs) {
                    $subtitles += New-Object -TypeName "PSObject" -Property @{'id'=$episode_id;'language'=$sub.language;'url'=$sub.webVtt;'season'="$season"}
                }
            }
        }

        foreach ($episode_raw in $episodes_req._embedded.instalments) {
            $episodes += New-Object -TypeName "PSObject" -Property @{'url'=$episode_raw._links.share.href;'season'="$season"}

            if (!($Drop_subtitles)) {
                $episode_id = $episode_raw.prfId
                $subs = $null
                $subs = (invoke-restmethod "https://psapi.nrk.no/playback/manifest/program/$episode_id").playable.subtitles
                foreach ($sub in $subs) {
                    $subtitles += New-Object -TypeName "PSObject" -Property @{'id'=$episode_id;'language'=$sub.language;'url'=$sub.webVtt;'season'="$season"}
                }
            }
        }
    }

    $episodes_count = $episodes.Count
    $download_count = 0

    foreach ($episode in $episodes) {
        if (!(Test-Path -PathType "Container" -Path $episode.season)){
            New-Item -ItemType "Directory" -Path $episode.season | Out-Null
        }
        Set-Location -Path $episode.season
        $download_count = $download_count + 1
        Write-Output "" "" "" "Downloading $download_count/$episodes_count"
        $episode.url = $episode.url -replace '{&autoplay,t}', ''
        & "$root_location\youtube-dl.exe" $episode.url
        Set-Location -Path "$root_location/downloads/$name"
    }
    if (!($Drop_subtitles)) {
        foreach ($subtitle in $subtitles) {
            $subtitle_id = $subtitle.id
            $subtitle_lang = $subtitle.language
            $subtitle_season = $subtitle.season
            $subtitle_url = $subtitle.url
            if (!(Test-Path -PathType "Container" -Path "$subtitle_season")){
                New-Item -ItemType "Directory" -Path "$subtitle_season"
            }
            Invoke-WebRequest -Uri "$subtitle_url" -OutFile "$subtitle_season/$subtitle_id.$subtitle_lang.vtt"
        }
    }
}

Set-Location "$root_location"
