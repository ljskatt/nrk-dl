param (
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Name,

    [Parameter()]
    [switch]
    $DropSubtitles,

    [Parameter()]
    [switch]
    $DropVideo,

    [Parameter()]
    [switch]
    $DropImages
)

function Get-Episodeinfo {
    if (!($DropVideo)) {
        $global:episodes += New-Object -TypeName "PSObject" -Property @{'url'=$episode_raw._links.share.href;'season'="$season"}
    }

    $episode_id = $episode_raw.prfId

    if (!($DropSubtitles)) {
        $subs = $null
        $subs = (invoke-restmethod "https://psapi.nrk.no/playback/manifest/program/$episode_id").playable.subtitles
        foreach ($sub in $subs) {
            $global:subtitles += New-Object -TypeName "PSObject" -Property @{'id'=$episode_id;'language'=$sub.language;'url'=$sub.webVtt;'season'="$season"}
        }
    }
    if (!($DropImages)) {
        $episode_image = $null
        $episode_image = ($episode_raw.image | Sort-Object -Property width -Descending).url[0]
        if ($episode_image){
            $global:images += New-Object -TypeName "PSObject" -Property @{'id'=$episode_id;'url'=$episode_image;'season'="$season"}
        }
    }
}

$ProgressPreference = 'SilentlyContinue'
$root_location = Get-Location

if (!(Test-Path -PathType "Leaf" -Path "youtube-dl.exe")) {
    Write-Output "Downloading youtube-dl"
    Invoke-WebRequest "https://youtube-dl.org/downloads/latest/youtube-dl.exe" -OutFile "youtube-dl.exe"
    Write-Output "Downloaded youtube-dl"
}

if (!(Test-Path -PathType "Leaf" -Path "ffmpeg.exe")) {
    Write-Output "Downloading ffmpeg"
    Invoke-WebRequest "https://cdn.serverhost.no/ljskatt/ffmpeg.exe" -OutFile "ffmpeg.exe"
    Write-Output "Downloaded ffmpeg"
}

if (!(Test-Path -PathType "Container" -Path "downloads")) {
    New-Item -ItemType "Directory" -Path "downloads" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads") {
        Write-Output "Opprettet downloads mappe"
    }
    else {
        Write-Warning "Kunne ikke opprette downloads mappe"
        exit
    }   
}

$seasons = $null
$standalone = $null
$series_req = Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/series/$name"
$seasons = $series_req._links.seasons.name
if ($seasons){
    if (!($DropImages)) {
        if ($series_req.sequential.image){
            $series_img_url = ($series_req.sequential.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.standard.image) {
            $series_img_url = ($series_req.standard.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.news.image) {
            $series_img_url = ($series_req.news.image | Sort-Object -Property width -Descending).url[0]
        }
        else {
            Write-Warning "Kunne ikke finne serie-bilde"
        }
    }
    $type = "series"
}
else {
    $standalone = (Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/programs/$name")._links.share.href
    if ($standalone){
        $type = "standalone"
    }
    else {
        Write-Warning "Kunne ikke finne program/serie"
        exit
    }
}

if (!(Test-Path -PathType "Container" -Path "downloads/$name")) {
    New-Item -ItemType "Directory" -Path "downloads/$name" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads/$name"){
        Write-Output "Opprettet $name mappe"
    }
    else {
        Write-Warning "Kunne ikke opprette $name mappe"
        exit
    }
}
Set-Location -Path "downloads/$name"

if ($type -eq "standalone"){
    $standalone = $standalone -replace '{&autoplay,t}', ''
    & "$root_location\youtube-dl.exe" "$standalone"
}

if ($type -eq "series"){
    $global:episodes = @()
    $global:subtitles = @()
    if (!($DropImages)) {
        $global:images = @()
        if ($series_img_url){
            Invoke-WebRequest -Uri "$series_img_url" -OutFile "show.jpg"
        }
    }
    foreach ($season in $seasons) {
        $episodes_req = Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/series/$name/seasons/$season"
        foreach ($episode_raw in $episodes_req._embedded.episodes) {
            Get-Episodeinfo
        }

        foreach ($episode_raw in $episodes_req._embedded.instalments) {
            Get-Episodeinfo
        }
    }

    $episodes = $global:episodes
    $subtitles = $global:subtitles
    $images = $global:images

    if (!($DropVideo)) {
        $episodes_count = $episodes.Count
        $download_count = 0
        foreach ($episode in $episodes) {
            if (!(Test-Path -PathType "Container" -Path $episode.season)){
                New-Item -ItemType "Directory" -Path $episode.season | Out-Null
            }
            Set-Location -Path $episode.season
            $download_count += 1
            Write-Output "" "" "Downloading ($download_count/$episodes_count)"
            $episode.url = $episode.url -replace '{&autoplay,t}', ''
            & "$root_location\youtube-dl.exe" $episode.url
            Set-Location -Path "$root_location/downloads/$name"
        }
    }
    if (!($DropSubtitles)) {
        Write-Output "" ""
        $subtitles_count = $subtitles.Count
        $sub_dl_count = 0
        foreach ($subtitle in $subtitles) {
            $sub_dl_count += 1
            Write-Output "Downloading subtitle ($sub_dl_count/$subtitles_count)"
            $subtitle_id = $subtitle.id
            $subtitle_lang = $subtitle.language
            $subtitle_season = $subtitle.season
            $subtitle_url = $subtitle.url
            if (!(Test-Path -PathType "Container" -Path "$subtitle_season")){
                New-Item -ItemType "Directory" -Path "$subtitle_season" | Out-Null
            }
            Invoke-WebRequest -Uri "$subtitle_url" -OutFile "$subtitle_season/$subtitle_id.$subtitle_lang.vtt"
        }
    }
    if (!($DropImages)) {
        Write-Output "" ""
        $images_count = $images.Count
        $img_dl_count = 0
        foreach ($image in $images) {
            $img_dl_count += 1
            Write-Output "Downloading image ($img_dl_count/$images_count)"
            $image_id = $image.id
            $image_season = $image.season
            $image_url = $image.url
            if (!(Test-Path -PathType "Container" -Path "$image_season")){
                New-Item -ItemType "Directory" -Path "$image_season" | Out-Null
            }
            Invoke-WebRequest -Uri "$image_url" -OutFile "$image_season/$image_id.jpg"
        }
    }
}

Set-Location "$root_location"