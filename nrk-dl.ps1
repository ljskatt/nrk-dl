param (
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Name,

    [Parameter()]
    [switch]
    $DropVideo,

    [Parameter()]
    [switch]
    $DropSubtitles,

    [Parameter()]
    [switch]
    $DropImages,

    [Parameter()]
    [switch]
    $LegacyFormatting,

    [Parameter()]
    [switch]
    $IncludeExtras,

    [Parameter()]
    [switch]
    $IncludeDescriptions,

    [Parameter()]
    [switch]
    $DisableSSLCertVerify, # This will only affect youtube-dl downloads and not connection to NRK api, SHOULD ONLY BE USED IF YOU GET ERRORS LIKE: [SSL: CERTIFICATE_VERIFY_FAILED]

    [Parameter()]
    [switch]
    $Debugging,

    [Parameter()]
    [switch]
    $Alignment_TheTVDB
)

function Format-Name {
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    $output = $Name
    $output = $output -replace "\?"
    $output = $output -replace ":"
    $output = $output -replace [char]0x0021 # !
    $output = $output -replace [char]0x0022 # "
    $output = $output -replace "\*"
    $output = $output -replace "/"
    $output = $output -replace '\\'
    return $output
}

function Get-Episodeinfo {
    $processed_url = $null
    if ($season -eq "extramaterial") {
        $season_filename = "00"
    }
    else {
        $season_filename = "{0:d2}" -f ([int]$season)
    }
    $season_dirname = "Season " + "$season_filename"
    $episode_title = Format-Name -Name ($episode_raw.titles.title)
    if ($episode_raw.sequenceNumber) {
        $seq_num = "{0:d2}" -f ($episode_raw.sequenceNumber)
    }
    else {
        $seq_num = $episode_raw.prfId
    }
    $episode_manifest = Invoke-RestMethod -Uri ("https://psapi.nrk.no/playback/manifest/program/" + $episode_raw.prfId)

    $processed_url = "https://tv.nrk.no" + $episode_raw._links.playback.href.Replace('/mediaelement','')

    if (-not ($DropVideo)) {
        $global:episodes += New-Object -TypeName "PSObject" -Property @{'id'=$episode_raw.prfId;'url'=$processed_url;'url_fallback'=$episode_manifest.playable.assets.url;'title'=$episode_title;'date'=$episode_raw.firstTransmissionDateDisplayValue;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
    }

    if (-not ($DropSubtitles)) {
        if ($episode_manifest.playable.subtitles.Count -gt 1) {
            Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object (" " + $episode_raw.prfId + " has more than 1 subtitle (" + $episode_manifest.playable.subtitles.Count + " subtitles), please double check ") -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        }
        foreach ($sub in $episode_manifest.playable.subtitles) {
            $global:subtitles += New-Object -TypeName "PSObject" -Property @{'id'=$episode_raw.prfId;'language'=$sub.language;'forced'=$sub.defaultOn;'url'=$sub.webVtt;'title'=$episode_title;'date'=$episode_raw.firstTransmissionDateDisplayValue;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
        }
    }

    if (-not ($DropImages)) {
        $episode_image = $null
        $episode_image = ($episode_raw.image | Sort-Object -Property width -Descending).url[0]
        if ($episode_image) {
            $global:images += New-Object -TypeName "PSObject" -Property @{'id'=$episode_raw.prfId;'url'=$episode_image;'title'=$episode_title;'date'=$episode_raw.firstTransmissionDateDisplayValue;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
        }
    }

    if ($IncludeDescriptions) {
        if ($episode_raw.titles.subtitle) {
            $global:descriptions += New-Object -TypeName "PSObject" -Property @{'desc'=$episode_raw.titles.subtitle;'id'=$episode_raw.prfId;'title'=$episode_title;'date'=$episode_raw.firstTransmissionDateDisplayValue;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
        }
    }
}

$ProgressPreference = 'SilentlyContinue'
$root_location = Get-Location

Write-Output ""
if ($IsWindows) {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Supported " -NoNewline
    Write-Output " Running script with Windows" ""
}
if ($IsMacOS) {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Supported " -NoNewline
    Write-Output " Running script with Mac OS" ""
}
if ($IsLinux) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Unsupported " -NoNewline
    Write-Output " Running script with Linux" ""
}

if ($DisableSSLCertVerify) {
    $ytdl_parameters = '--no-check-certificate'
}
else {
    $ytdl_parameters = ''
}

if ($IsMacOS -or $IsLinux) {
    if (Get-Command -Name "youtube-dl") {
        Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " youtube-dl OK " -NoNewline; Write-Host -Object "|"; Write-Host ""
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "White" -Object " youtube-dl is missing, please install it first " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
    }
}
else {
    if (-not (Test-Path -PathType "Leaf" -Path "youtube-dl.exe")) {
        $downloadaccept = Read-Host -Prompt "youtube-dl.exe (required-package) is not installed, do you want us to download it? Source: https://youtube-dl.org/downloads/latest/youtube-dl.exe (Y/n)`n"
        if ($downloadaccept -in '','y','yes') {
            Write-Output "" "Downloading youtube-dl"
            Invoke-WebRequest -Uri "https://youtube-dl.org/downloads/latest/youtube-dl.exe" -OutFile "youtube-dl.exe"
            if (Test-Path -PathType "Leaf" -Path "youtube-dl.exe") {
                Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Success " -NoNewline; Write-Host -Object "|"; Write-Host ""
            }
            else {
                Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Failed " -NoNewline; Write-Host -Object "|"
                exit
            }
        }
        else {
            Write-Host -BackgroundColor "Red" -ForegroundColor "White" -Object " Terminated due to missing package " -NoNewline; Write-Host -Object "|"
            exit
        }
    }
    if (-not (Test-Path -Path "C:\Windows\System32\MSVCR100.dll" -PathType "leaf")) {
        Write-Host -Object ""
        Write-Host -BackgroundColor "Red" -ForegroundColor "White" -Object " MSVCR100.dll (required by youtube-dl) is missing, please install missing C++ library: " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        Write-Host -BackgroundColor "Red" -ForegroundColor "White" -Object " https://www.microsoft.com/en-US/download/details.aspx?id=8328 " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        Write-Host -Object ""
    }
}

if ($IsMacOS -or $IsLinux) {
    if (Get-Command -Name "ffmpeg") {
        Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ffmpeg OK " -NoNewline; Write-Host -Object "|"; Write-Host ""
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "White" -Object " ffmpeg is missing, please install it first " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
    }
}
else {
    if (-not (Test-Path -PathType "Leaf" -Path "ffmpeg.exe")) {
        $downloadaccept = $null
        $downloadaccept = Read-Host -Prompt "ffmpeg.exe (required-package) is not installed, do you want us to download it? Source: https://cdn.serverhost.no/ljskatt/ffmpeg.exe (Y/n)`n"
        if ($downloadaccept -in '','y','yes') {
            Write-Output "Downloading ffmpeg"
            Invoke-WebRequest -Uri "https://cdn.serverhost.no/ljskatt/ffmpeg.exe" -OutFile "ffmpeg.exe"
            if (Test-Path -PathType "Leaf" -Path "ffmpeg.exe") {
                Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Success " -NoNewline; Write-Host -Object "|"; Write-Host ""
            }
            else {
                Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Failed " -NoNewline; Write-Host -Object "|"
                exit
            }
        }
        else {
            Write-Host -BackgroundColor "Red" -ForegroundColor "White" -Object " Terminated due to missing package " -NoNewline; Write-Host -Object "|"
            exit
        }
    }
}

if (-not (Test-Path -PathType "Container" -Path "downloads")) {
    New-Item -ItemType "Directory" -Path "downloads" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads") {
        Write-Output "Created downloads folder" ""
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Could not create downloads folder " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        exit
    }   
}

$seasons = $null
$standalone = $null
$series_req = Invoke-RestMethod -Uri "https://psapi.nrk.no/tv/catalog/series/$name"
$seasons = $series_req._links.seasons.name

if ($Alignment_TheTVDB) {
    $alignment_file = "alignment-thetvdb-$name.json"
    if (Test-Path -Path $alignment_file) {
        $alignment = Get-Content -Path $alignment_file | ConvertFrom-Json
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Alignmentfile ($alignment_file) does not exist " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        exit
    }
}

if ($seasons) {
    if (-not ($DropImages)) {
        if ($series_req.sequential.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req.sequential.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.standard.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req.standard.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.news.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req.news.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req._embedded.seasons.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req._embedded.seasons.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        else {
            Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object " Could not find backdrop-image " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        }

        if ($series_req.sequential.posterImage -ne $null) {
            $series_poster_url = ($series_req.sequential.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.standard.posterImage -ne $null) {
            $series_poster_url = ($series_req.standard.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.news.posterImage -ne $null) {
            $series_poster_url = ($series_req.news.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req._embedded.seasons.posterImage -ne $null) {
            $series_poster_url = ($series_req._embedded.seasons.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.sequential.image -ne $null) {
            $series_poster_url = ($series_req.sequential.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.standard.image -ne $null) {
            $series_poster_url = ($series_req.standard.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.news.image -ne $null) {
            $series_poster_url = ($series_req.news.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req._embedded.seasons.image -ne $null) {
            $series_poster_url = ($series_req._embedded.seasons.image | Sort-Object -Property width -Descending).url[0]
        }
        else {
            Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Could not find poster-image " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        }
    }
    $type = "series"
    $seriestype = $series_req.seriesType

    if ($series_req.sequential.titles.title) {
        $seriestitle = Format-Name -Name ($series_req.sequential.titles.title)
    }
    elseif ($series_req.standard.titles.title) {
        $seriestitle = Format-Name -Name ($series_req.standard.titles.title)
    }
}
else {
    $standalone_req = (Invoke-RestMethod -Uri "https://psapi.nrk.no/tv/catalog/programs/$name")
    $standalone = $standalone_req._links.share.href
    if ($standalone_req) {
        $type = "standalone"
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Could not find program/series " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        exit
    }
}

Write-Output "--------------------" "" "$name (Type: $type)" "Download folder: $root_location\downloads\$name" ""
Write-Host "Video:                 |" -NoNewline
if ($DropVideo) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}

Write-Host "Images:                |" -NoNewline
if ($DropImages) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}

Write-Host "Subtitles:             |" -NoNewline
if ($DropSubtitles) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}

Write-Host "Legacy Formatting:     |" -NoNewline
if ($LegacyFormatting) {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}

Write-Host "Include Extras:        |" -NoNewline
if ($IncludeExtras) {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}

Write-Host "Include Descriptions:  |" -NoNewline
if ($IncludeDescriptions) {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}

Write-Host "Alignment TheTVDB:     |" -NoNewline
if ($Alignment_TheTVDB) {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}

Write-Host "SSL Cert Verification: |" -NoNewline
if ($DisableSSLCertVerify) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF " -NoNewline; Write-Host -Object "|"
}
else {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON " -NoNewline; Write-Host -Object "|"
}

Write-Output "" "--------------------"
Read-Host -Prompt "Press enter to continue, CTRL + C to quit"

if (-not (Test-Path -PathType "Container" -Path "downloads/$name")) {
    New-Item -ItemType "Directory" -Path "downloads/$name" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads/$name") {
        Write-Output "Created $name folder" ""
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Could not create $name folder " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        exit
    }
}
Set-Location -Path "downloads/$name"

if ($type -eq "standalone") {
    if (-not ($DropVideo)) {
        $standalone = $standalone -replace '{&autoplay,t}', ''
        if ($Debugging) {
            Write-Output ("Video: Downloading " + $standalone)
        }
        else {
            Write-Output "Video: Downloading"
        }
        if ($IsMacOS -or $IsLinux) {
            youtube-dl "$standalone" $ytdl_parameters
        }
        else {
            & "$root_location\youtube-dl.exe" "$standalone" $ytdl_parameters
        }
        Write-Output "Video: Downloaded"
    }
    if (-not ($DropSubtitles)) {
        $subtitles = (Invoke-RestMethod -Uri "https://psapi.nrk.no/playback/manifest/program/$name").playable.subtitles
        Write-Output "Subtitles: Downloading"
        if ($subtitles.Count -gt 1) {
            Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object (" $name has more than 1 subtitle (" + $subtitles.Count + " subtitles), please double check ")
        }
        foreach ($subtitle in $subtitles) {
            if ($subtitle.defaultOn -eq $true) {
                $sub_forced = ".forced"
            }
            else {
                $sub_forced = ""
            }
            Invoke-WebRequest -Uri ($subtitle.webVtt) -OutFile ("$name" + "." + $subtitle.language + "$sub_forced.vtt")
        }
        Write-Output "Subtitles: Done"
    }
    if (-not ($DropImages)) {
        Write-Output "Images: Downloading"
        if ($standalone_req.programInformation.backdropImage) {
            Invoke-WebRequest -Uri (($standalone_req.programInformation.backdropImage | Sort-Object -Property width -Descending).url[0]) -OutFile "background.jpg"
        }
        if ($standalone_req.programInformation.posterImage) {
            Invoke-WebRequest -Uri (($standalone_req.programInformation.posterImage | Sort-Object -Property width -Descending).url[0]) -OutFile "poster.jpg"
        }
        elseif ($standalone_req.programInformation.image) {
            Invoke-WebRequest -Uri (($standalone_req.programInformation.image | Sort-Object -Property width -Descending).url[0]) -OutFile "poster.jpg"
        }
        else {
            Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Could not find poster " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
        }
        Write-Output "Images: Done"
    }
}

if ($type -eq "series") {
    $global:episodes = @()
    $global:subtitles = @()
    $global:descriptions = @()
    if (-not ($DropImages)) {
        $global:images = @()
        if ($series_backdrop_url) {
            Invoke-WebRequest -Uri "$series_backdrop_url" -OutFile "background.jpg"
        }
        if ($series_poster_url) {
            Invoke-WebRequest -Uri "$series_poster_url" -OutFile "poster.jpg"
        }
    }
    foreach ($season in $seasons) {
        $episodes_req = Invoke-RestMethod -Uri "https://psapi.nrk.no/tv/catalog/series/$name/seasons/$season"
        foreach ($episode_raw in $episodes_req._embedded.episodes) {
            Get-Episodeinfo
        }

        foreach ($episode_raw in $episodes_req._embedded.instalments) {
            Get-Episodeinfo
        }
    }
    if ($series_req._embedded.extraMaterial._links.self.href -ne $null) {
        $extras_req = Invoke-RestMethod -Uri ("https://psapi.nrk.no" + $series_req._embedded.extraMaterial._links.self.href)
        $season = "00"
        foreach ($episode_raw in $extras_req._embedded.episodes) {
            Get-Episodeinfo
        }
    }

    $episodes = $global:episodes
    $subtitles = $global:subtitles
    $images = $global:images
    $descriptions = $global:descriptions

    Write-Output "" ""

    if (-not ($DropVideo)) {
        $episodes_count = $episodes.Count
        $download_count = 0
        foreach ($episode in $episodes) {
            $download_count += 1
            if (-not (Test-Path -PathType "Container" -Path ($episode.seasondn))) {
                New-Item -ItemType "Directory" -Path ($episode.seasondn) | Out-Null
            }
            $episode.url = $episode.url -replace '{&autoplay,t}', ''

            if ($Alignment_TheTVDB) {
                $episode_aligment = $alignment | Where-Object {$_.id -eq $episode.id}
                if ($episode_aligment.count -eq 1) {
                    if ($episode_aligment.episode_code) {
                        $outfile = ($episode_aligment.seasondn + "/$seriestitle - " + $episode_aligment.episode_code + ".mp4")
                    }
                    else {
                        Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object (' Episode is in alignment file, but does not have a alignment, falling back on s' + $episode.seasonfn + 'e' + $episode.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                        $outfile = ($episode.seasondn + "/$seriestitle - s" + $episode.seasonfn + "e" + $episode.seq_num + ".mp4")
                    }
                }
                else {
                    Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object ($episode_aligment.count + ' matches on episode: ' + $episode.id + ' (s' + $episode.seasonfn + 'e' + $episode.seq_num + '), but does not have a alignment, falling back on: s' + $episode.seasonfn + 'e' + $episode.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                }
            }
            elseif (($seriestype -eq "sequential") -and (-not ($LegacyFormatting))) {
                $outfile = ($episode.seasondn + "/$seriestitle - s" + $episode.seasonfn + "e" + $episode.seq_num + ".mp4")
            }
            elseif (($episode.date) -and (-not ($LegacyFormatting))) {
                $outfile = ($episode.seasondn + "/$seriestitle - " + $episode.date + " - " + $episode.title + ".mp4")
            }
            else {
                $outfile = ($episode.seasondn + "/$name - " + $episode.id + ".mp4")
            }

            if (Test-Path -PathType "Leaf" -Path "$outfile") {
                Write-Output "Episode ($download_count/$episodes_count) exists: $outfile"
            }
            else {
                if ($Debugging) {
                    Write-Output ("Downloading ($download_count/$episodes_count) " + $episode.url)
                }
                else {
                    Write-Output "Downloading ($download_count/$episodes_count)"
                }
                if ($IsMacOS -or $IsLinux) {
                    youtube-dl -q ($episode.url) -o "$outfile" $ytdl_parameters
                }
                else {
                    & "$root_location\youtube-dl.exe" -q ($episode.url) -o "$outfile" $ytdl_parameters
                }
                if (Test-Path -PathType "Leaf" -Path "$outfile") {
                    Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Success " -NoNewline; Write-Host -Object "|"
                }
                else {
                    if ($episode.url_fallback) {
                        Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object " Download failed, trying fallback url " -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"
                        if ($IsMacOS -or $IsLinux) {
                            youtube-dl -q ($episode.url_fallback) -o "$outfile" $ytdl_parameters
                        }
                        else {
                            & "$root_location\youtube-dl.exe" -q ($episode.url_fallback) -o "$outfile" $ytdl_parameters
                        }
                        if (Test-Path -PathType "Leaf" -Path "$outfile") {
                            Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Success " -NoNewline; Write-Host -Object "|"
                        }
                        else {
                            Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Failed " -NoNewline; Write-Host -Object "|"
                        }
                    }
                    else {
                        Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Failed " -NoNewline; Write-Host -Object "|"
                    }
                }
            }
            Write-Output ""
        }
        Write-Output ""
    }
    if (-not ($DropSubtitles)) {
        $subtitles_count = $subtitles.Count
        $sub_dl_count = 0
        foreach ($subtitle in $subtitles) {
            $sub_dl_count += 1
            $sub_forced = ""

            if ($subtitle.defaultOn -eq $true) {
                $sub_forced = ".forced"
            }

            if (-not (Test-Path -PathType "Container" -Path ($subtitle.seasondn))) {
                New-Item -ItemType "Directory" -Path ($subtitle.seasondn) | Out-Null
            }

            if ($Alignment_TheTVDB) {
                $episode_aligment = $alignment | Where-Object {$_.id -eq $subtitle.id}
                if ($episode_aligment.count -eq 1) {
                    if ($episode_aligment.episode_code) {
                        $outfile = ($episode_aligment.seasondn + "/$seriestitle - " + $episode_aligment.episode_code + "." + $subtitle.language + "$sub_forced.vtt")
                    }
                    else {
                        Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object (' Episode is in alignment file, but does not have a alignment, falling back on s' + $subtitle.seasonfn + 'e' + $subtitle.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                        $outfile = ($subtitle.seasondn + "/$seriestitle - s" + $subtitle.seasonfn + "e" + $subtitle.seq_num + "." + $subtitle.language + "$sub_forced.vtt")
                    }
                }
                else {
                    Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object ($episode_aligment.count + ' matches on episode: ' + $subtitle.id + ' (s' + $subtitle.seasonfn + 'e' + $subtitle.seq_num + '), but does not have a alignment, falling back on: s' + $subtitle.seasonfn + 'e' + $subtitle.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                    $outfile = ($subtitle.seasondn + "/$seriestitle - s" + $subtitle.seasonfn + "e" + $subtitle.seq_num + "." + $subtitle.language + "$sub_forced.vtt")
                }
            }
            elseif (($seriestype -eq "sequential") -and (-not ($LegacyFormatting))) {
                $outfile = ($subtitle.seasondn + "/$seriestitle - s" + $subtitle.seasonfn + "e" + $subtitle.seq_num + "." + $subtitle.language + "$sub_forced.vtt")
            }
            elseif (($subtitle.date) -and (-not ($LegacyFormatting))) {
                $outfile = ($subtitle.seasondn + "/$seriestitle - " + $subtitle.date + " - " + $subtitle.title + "." + $subtitle.language + "$sub_forced.vtt")
            }
            else {
                $outfile = ($subtitle.seasondn + "/" + $subtitle.id + "." + $subtitle.language + "$sub_forced.vtt")
            }
            if (Test-Path -PathType "Leaf" -Path "$outfile") {
                Write-Output "Subtitle ($sub_dl_count/$subtitles_count) already exists, skipping ($outfile)"
            }
            else {
                if ($Debugging) {
                    Write-Host -Object ("Downloading subtitle ($sub_dl_count/$subtitles_count) " + $subtitle.url) -NoNewline
                }
                else {
                    Write-Host -Object "Downloading subtitle ($sub_dl_count/$subtitles_count) " -NoNewline
                }
                Invoke-WebRequest -Uri ($subtitle.url) -OutFile "$outfile"
                if (Test-Path -PathType "Leaf" -Path "$outfile") {
                    Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Success " -NoNewline; Write-Host -Object "|"
                }
                else {
                    Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Failed "-NoNewline; Write-Host -Object "|"
                }
            }
        }
        Write-Output ""
    }
    if (-not ($DropImages)) {
        $images_count = $images.Count
        $img_dl_count = 0
        foreach ($image in $images) {
            $img_dl_count += 1
            if (-not (Test-Path -PathType "Container" -Path ($image.seasondn))) {
                New-Item -ItemType "Directory" -Path ($image.seasondn) | Out-Null
            }

            if ($Alignment_TheTVDB) {
                $episode_aligment = $alignment | Where-Object {$_.id -eq $image.id}
                if ($episode_aligment.count -eq 1) {
                    if ($episode_aligment.episode_code) {
                        $outfile = ($episode_aligment.seasondn + "/$seriestitle - " + $episode_aligment.episode_code + ".jpg")
                    }
                    else {
                        Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object (' Episode is in alignment file, but does not have a alignment, falling back on s' + $image.seasonfn + 'e' + $image.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                        $outfile = ($image.seasondn + "/$seriestitle - s" + $image.seasonfn + "e" + $image.seq_num + ".jpg")
                    }
                }
                else {
                    Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object ($episode_aligment.count + ' matches on episode: ' + $image.id + ' (s' + $image.seasonfn + 'e' + $image.seq_num + '), but does not have a alignment, falling back on: s' + $image.seasonfn + 'e' + $image.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                    $outfile = ($image.seasondn + "/$seriestitle - s" + $image.seasonfn + "e" + $image.seq_num + ".jpg")
                }
            }
            elseif (($seriestype -eq "sequential") -and (-not ($LegacyFormatting))) {
                $outfile = ($image.seasondn + "/$seriestitle - s" + $image.seasonfn + "e" + $image.seq_num + ".jpg")
            }
            elseif (($image.date) -and (-not ($LegacyFormatting))) {
                $outfile = ($image.seasondn + "/$seriestitle - " + $image.date + " - " + $image.title + ".jpg")
            }
            else {
                $outfile = ($image.seasondn + "/" + $image.id + ".jpg")
            }
            
            if (Test-Path -PathType "Leaf" -Path "$outfile") {
                Write-Output "Image ($img_dl_count/$images_count) already exists, skipping"
            }
            else {
                if ($Debugging) {
                    Write-Host -Object ("Downloading image ($img_dl_count/$images_count) " + $image.url) -NoNewline
                }
                else {
                    Write-Host -Object "Downloading image ($img_dl_count/$images_count) " -NoNewline
                }
                Invoke-WebRequest -Uri ($image.url) -OutFile "$outfile"
                if (Test-Path -PathType "Leaf" -Path "$outfile") {
                    Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Success " -NoNewline; Write-Host -Object "|"
                }
                else {
                    Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Failed "-NoNewline; Write-Host -Object "|"
                }
            }
        }
        Write-Output ""
    }
    if ($IncludeDescriptions) {
        $desc_count = $descriptions.Count
        $desc_dl_count = 0
        foreach ($description in $descriptions) {
            $desc_dl_count += 1
            if (-not (Test-Path -PathType "Container" -Path ($description.seasondn))) {
                New-Item -ItemType "Directory" -Path ($description.seasondn) | Out-Null
            }

            if ($Alignment_TheTVDB) {
                $episode_aligment = $alignment | Where-Object {$_.id -eq $description.id}
                if ($episode_aligment.count -eq 1) {
                    if ($episode_aligment.episode_code) {
                        $outfile = ($episode_aligment.seasondn + "/$seriestitle - " + $episode_aligment.episode_code + "-description.txt")
                    }
                    else {
                        Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object (' Episode is in alignment file, but does not have a alignment, falling back on s' + $description.seasonfn + 'e' + $description.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                        $outfile = ($description.seasondn + "/$seriestitle - s" + $description.seasonfn + "e" + $description.seq_num + "-description.txt")
                    }
                }
                else {
                    Write-Host -BackgroundColor "Yellow" -ForegroundColor "Black" -Object ($episode_aligment.count + ' matches on episode: ' + $description.id + ' (s' + $description.seasonfn + 'e' + $description.seq_num + '), but does not have a alignment, falling back on: s' + $description.seasonfn + 'e' + $description.seq_num + ' ') -NoNewline; Write-Host -ForegroundColor "DarkGray" -Object "|"; Write-Host -Object ""
                    $outfile = ($description.seasondn + "/$seriestitle - s" + $description.seasonfn + "e" + $description.seq_num + "-description.txt")
                }
            }
            elseif (($seriestype -eq "sequential") -and (-not ($LegacyFormatting))) {
                $outfile = ($description.seasondn + "/$seriestitle - s" + $description.seasonfn + "e" + $description.seq_num + "-description.txt")
            }
            elseif (($description.date) -and (-not($LegacyFormatting))) {
                $outfile = ($description.seasondn + "/$seriestitle - " + $description.date + " - " + $description.title + "-description.txt")
            }
            else {
                $outfile = ($description.seasondn + "/" + $description.id + "-description.txt")
            }
            
            if (Test-Path -PathType "Leaf" -Path "$outfile") {
                Write-Output "Description ($desc_dl_count/$desc_count) already exists, skipping"
            }
            else {
                Write-Host -Object "Writing description ($desc_dl_count/$desc_count) " -NoNewline
                $description.desc | Out-File -FilePath "$outfile" -NoNewline
                if (Test-Path -PathType "Leaf" -Path "$outfile") {
                    Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " Success " -NoNewline; Write-Host -Object "|"
                }
                else {
                    Write-Host -Object "|" -NoNewline; Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " Failed "-NoNewline; Write-Host -Object "|"
                }
            }
        }
    }
}

Set-Location -Path "$root_location"