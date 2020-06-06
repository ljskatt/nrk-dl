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
    $DropImages,

    [Parameter()]
    [switch]
    $LegacySequentialFormatting
)

function Get-Episodeinfo {
    $episode_id = $episode_raw.prfId
    $season_filename = "{0:d2}" -f ([int]$season)
    $season_dirname = "Season " + "$season_filename"
    if ($episode_raw.sequenceNumber) {
        $seq_num = "{0:d2}" -f ($episode_raw.sequenceNumber)
    }

    if (!($DropVideo)) {
        $global:episodes += New-Object -TypeName "PSObject" -Property @{'url'=$episode_raw._links.share.href;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
    }

    if (!($DropSubtitles)) {
        $subs = $null
        $subs = (invoke-restmethod "https://psapi.nrk.no/playback/manifest/program/$episode_id").playable.subtitles
        foreach ($sub in $subs) {
            $global:subtitles += New-Object -TypeName "PSObject" -Property @{'id'=$episode_id;'language'=$sub.language;'url'=$sub.webVtt;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
        }
    }

    if (!($DropImages)) {
        $episode_image = $null
        $episode_image = ($episode_raw.image | Sort-Object -Property width -Descending).url[0]
        if ($episode_image){
            $global:images += New-Object -TypeName "PSObject" -Property @{'id'=$episode_id;'url'=$episode_image;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
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
    $seriestype = $series_req.seriesType

    if ($seriestype -eq "sequential") {
        $seriestitle = $series_req.sequential.titles.title
        $seriestitle = $seriestitle -replace "\?"
        $seriestitle = $seriestitle -replace ":"
        $seriestitle = $seriestitle -replace [char]0x0021 # !
        $seriestitle = $seriestitle -replace [char]0x0022 # "
        $seriestitle = $seriestitle -replace "\*"
        $seriestitle = $seriestitle -replace "/"
        $seriestitle = $seriestitle -replace '\\'
    }
}
else {
    $standalone_req = (Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/programs/$name")
    $standalone = $standalone_req._links.share.href
    if ($standalone_req){
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
    if (!($DropVideo)) {

        $standalone = $standalone -replace '{&autoplay,t}', ''
        & "$root_location\youtube-dl.exe" "$standalone"
    }
    if (!($DropSubtitles)) {
        $subtitles = (Invoke-RestMethod "https://psapi.nrk.no/playback/manifest/program/$name").playable.subtitles
        Write-Output "Subtitles: Downloading"
        foreach ($subtitle in $subtitles) {
            Invoke-WebRequest ($subtitle.webVtt) -OutFile ("$name" + "." + $subtitle.language + ".vtt")
        }
        Write-Output "Subtitles: Done"
    }
    if (!($DropImages)) {
        Write-Output "Images: Downloading"
        Invoke-WebRequest -Uri (($standalone_req.programInformation.image | Sort-Object -Property width -Descending).url[0]) -OutFile "show.jpg"
        Write-Output "Images: Done"
    }
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
            $download_count += 1
            if (!(Test-Path -PathType "Container" -Path ($episode.seasondn))) {
                New-Item -ItemType "Directory" -Path ($episode.seasondn) | Out-Null
            }
            Write-Output "" "" "Downloading ($download_count/$episodes_count)"
            $episode.url = $episode.url -replace '{&autoplay,t}', ''

            if (($seriestype -eq "sequential") -and (!($LegacySequentialFormatting))) {
                & "$root_location\youtube-dl.exe" ($episode.url) -o ($episode.seasondn + "/$seriestitle - s" + $episode.seasonfn + "e" + $episode.seq_num + ".mp4")
            }
            else {
                Set-Location -Path ($episode.seasondn)
                & "$root_location\youtube-dl.exe" ($episode.url)
                Set-Location -Path "$root_location/downloads/$name"
            }
        }
    }
    if (!($DropSubtitles)) {
        Write-Output "" ""
        $subtitles_count = $subtitles.Count
        $sub_dl_count = 0
        foreach ($subtitle in $subtitles) {
            $sub_dl_count += 1
            Write-Output "Downloading subtitle ($sub_dl_count/$subtitles_count)"
            if (!(Test-Path -PathType "Container" -Path ($subtitle.seasondn))){
                New-Item -ItemType "Directory" -Path ($subtitle.seasondn) | Out-Null
            }

            if (($seriestype -eq "sequential") -and (!($LegacySequentialFormatting))) {
                Invoke-WebRequest -Uri ($subtitle.url) -OutFile ($subtitle.seasondn + "/$seriestitle - s" + $subtitle.seasonfn + "e" + $subtitle.seq_num + "." + $subtitle.language + ".vtt")
            }
            else {
                Invoke-WebRequest -Uri ($subtitle.url) -OutFile ($subtitle.seasondn + "/" + $subtitle.id + "." + $subtitle.language + ".vtt")
            }
        }
    }
    if (!($DropImages)) {
        Write-Output "" ""
        $images_count = $images.Count
        $img_dl_count = 0
        foreach ($image in $images) {
            $img_dl_count += 1
            Write-Output "Downloading image ($img_dl_count/$images_count)"
            if (!(Test-Path -PathType "Container" -Path ($image.seasondn))){
                New-Item -ItemType "Directory" -Path ($image.seasondn) | Out-Null
            }

            if (($seriestype -eq "sequential") -and (!($LegacySequentialFormatting))) {
                Invoke-WebRequest -Uri ($image.url) -OutFile ($image.seasondn + "/$seriestitle - s" + $image.seasonfn + "e" + $image.seq_num + ".jpg")
            }
            else {
                Invoke-WebRequest -Uri ($image.url) -OutFile ($image.seasondn + "/" + $image.id + ".jpg")
            }
        }
    }
}

Set-Location "$root_location"