# NRK-DL

Lovligheten rundt dette verktøyet er uklart, anbefaler å bare benytte verktøyet til privat, ikke-kommersiell bruk.<br>
**Bruk av verktøyet gjøres på egen risiko.** [Opphavsrett på NRK](https://www.nrk.no/etikk/opphavsrett-pa-nrk.no-1.2843522)

Dette prosjektet ble startet etter at det ble kjent at NRK innhold fra før 1997 kan bli borte fra NRK om det ikke kommer en ny avtale på plass med Norwaco, derfor bestemte jeg meg for å lage et script som gjør at man lett kan laste ned innhold fra NRK, slik at man kan holde på denne arven.

Avtalen med Norwaco ble fornyet, derfor ble motivet til dette prosjektet endret til å fokusere på å laste ned programmer/serier som stadig blir fjernet fra NRK sitt arkiv, rapporter over hvilke programmer/serier som blir fjernet, kan du finne her: [NRK-Expire](https://github.com/ljskatt/nrk-expire)

## Windows

### Dependencies

Dette vil automatisk bli lastet ned når du kjører scriptet:

- yt-dlp.exe - Denne pakken gjør at man kan laste ned videofilene fra NRK sine servere
- ffmpeg.exe - yt-dlp benytter dette programmet når det skal slå sammen video og lyd

### Start

Last ned filen og kjør kommandoen for å begynne å laste ned episoden/episoder, scriptet vil selv laste ned dependencies som den trenger.

`.\nrk-dl.ps1 [-Name] <program> [-DropVideo] [-DropSubtitles] [-DropImages] [-SeasonFilter <season>] [-LegacyFormatting] [-IncludeExtras] [-IncludeDescriptions] [-DisableSSLCertVerify] [-Debugging] [-Alignment_TheTVDB]`

### Eksempel

```
https://tv.nrk.no/program/FDRI40003290
https://tv.nrk.no/serie/fleksnes
```

`.\nrk-dl.ps1 "FDRI40003290"`
Scriptet vil laste ned programmet

`.\nrk-dl.ps1 "fleksnes"`
Scriptet vil laste ned alle episodene av Fleksnes

`.\nrk-dl.ps1 "fantorangen" -SeasonFilter 3`
Scriptet vil laste ned alle episodene av Fantorangen i sesong 3

### Alignment filer

- [x] Poirot - [Issue](https://github.com/ljskatt/nrk-dl/issues/5)
- [ ] Vera - [Issue](https://github.com/ljskatt/nrk-dl/issues/4)

## Linux
:warning: &nbsp; Dette scriptet fungerer ikke lenger, dette blir oppdatert fortløpende, men PowerShell (Windows) er prioritert først :warning:

### Dependencies

Dette vil automatisk bli lastet ned når du kjører scriptet (Støtter Debian-baserte, Arch-baserte distroer og CentOS for øyeblikket)

- yt-dlp - Denne pakken gjør at man kan laste ned videofilen fra NRK sine servere
- curl - Denne pakken trenger man for å kunne kommunisere med NRK sitt API
- jq - Denne pakken brukes til å hente ut informasjon fra responsen til NRK sitt API
- screen - Denne pakken brukes når man laster ned parallelt

### Start
Scriptet kan startes med å bare kjøre det, eller legge til flere parametere i kommandoen slik at man kjappere kan laste ned flere serier/programmer.
`./nrk-dl.sh`

:warning: Ikke start scriptet med `sh nrk-dl.sh`, da vil det oppstå feil :warning:

### Parametere

- Kjøre det parallelt: (0/1)
- Hvor mange nedlastninger skal kjøre samtidig: (2-99)
- Program: (program)

`./nrk-dl.sh "<0/1>" "<2-99>" "<program>"`


### Eksempel

`./nrk-dl.sh "1" "5" "fleksnes"`

Nedlastningen vil kjøre parallelt med 5 samtidige nedlastninger av Fleksnes

<br>

`./nrk-dl.sh "0" "" "fleksnes"`

Nedlastningen av Fleksnes vil kjøre serielt (laste ned en video om gangen)
