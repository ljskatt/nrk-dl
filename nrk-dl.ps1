$program = $args[0]
$root_location = Get-Location

if ($program -eq ""){
    Write-Output "Missing program name"
    exit
}

$program = "fleksnes"

if (!(Test-Path "youtube-dl.exe")) {
    Invoke-WebRequest "https://youtube-dl.org/downloads/latest/youtube-dl.exe" -OutFile "youtube-dl.exe"
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

$seasons_req = Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/series/$program"
$seasons = $seasons_req._links.seasons.name
if ($null -eq $seasons) {
    Write-Output "Kunne ikke finne program/serie"
    exit
}

if (!(Test-Path "downloads/$program")) {
    New-Item -ItemType Directory "downloads/$program" | Out-Null
    if (Test-Path "downloads/$program"){
        Write-Output "Opprettet $program mappe"
    }
    else {
        Write-Output "Kunne ikke opprette $program mappe"
        exit
    }
}

Set-Location "downloads/$program"
$episodes = @{}

foreach ($season in $seasons) {
    $episodes_req = Invoke-RestMethod "https://psapi.nrk.no/tv/catalog/series/$program/seasons/$season"
    $episodes_raw = $episodes_req._embedded.instalments.prfId

    foreach ($episode_raw in $episodes_raw) {
        $episodes = $episodes + @{$episode_raw=$episode_raw}
    } 
}

$episodes_count = $episodes.Values.Count
$download_count = 0

foreach ($episode in $episodes.Values) {
    $download_count = $download_count + 1
    Write-Output "" "" "" "Downloading $download_count/$episodes_count"
    $episode = $episode -replace '{&autoplay,t}', ''
    & "$root_location\youtube-dl.exe" "https://tv.nrk.no/se?v=$episode"
}

Set-Location "$root_location"
