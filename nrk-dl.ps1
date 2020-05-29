$ProgressPreference = 'SilentlyContinue'
$name = $args[0]
$root_location = Get-Location

if (!(Test-Path "youtube-dl.exe")) {
    Write-Output "Downloading youtube-dl"
    Invoke-WebRequest "https://youtube-dl.org/downloads/latest/youtube-dl.exe" -OutFile "youtube-dl.exe"
    Write-Output "Downloaded youtube-dl"
}

if (!(Test-Path "downloads")) {
    New-Item -ItemType Directory "downloads" | Out-Null
    if (Test-Path "downloads") {
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

if (!(Test-Path "downloads/$name")) {
    New-Item -ItemType Directory "downloads/$name" | Out-Null
    if (Test-Path "downloads/$name"){
        Write-Output "Opprettet $name mappe"
    }
    else {
        Write-Output "Kunne ikke opprette $name mappe"
        exit
    }
}
Set-Location "downloads/$name"

if ($type -eq "standalone"){
    $standalone = $standalone -replace '{&autoplay,t}', ''
    & "$root_location\youtube-dl.exe" "$standalone"
}

if ($type -eq "series"){
    $episodes = @{}
    foreach ($season in $seasons) {
        $episodes_req = Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/series/$name/seasons/$season"
        $episodes_raw = $episodes_req._embedded.episodes._links.share.href

        foreach ($episode_raw in $episodes_raw) {
            $episodes = $episodes + @{$episode_raw=$episode_raw}
        }

        $episodes_raw2 = $episodes_req._embedded.instalments._links.share.href

        foreach ($episode_raw in $episodes_raw2) {
            $episodes = $episodes + @{$episode_raw=$episode_raw}
        }
    }

    $episodes_count = $episodes.Values.Count
    $download_count = 0

    foreach ($episode in $episodes.Values) {
        $download_count = $download_count + 1
        Write-Output "" "" "" "Downloading $download_count/$episodes_count"
        $episode = $episode -replace '{&autoplay,t}', ''
        & "$root_location\youtube-dl.exe" "$episode"
    }
}

Set-Location "$root_location"
