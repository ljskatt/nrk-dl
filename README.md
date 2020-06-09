# NRK-DL

Dette prosjektet ble startet etter at det ble kjent at NRK innhold fra før 1997 kan bli borte fra NRK om det ikke kommer en ny avtale på plass med Norwaco, derfor bestemte jeg meg for å lage et script som gjør at man lett kan laste ned innehold fra NRK, slik at man kan holde på denne arven.

## Windows

### Dependencies

Dette vil automatisk bli lastet ned når du kjører scriptet

- youtube-dl.exe - Denne pakken gjør at man kan laste ned videofilen fra NRK sine servere

### Start

Last ned filen og kjør kommandoen for å begynne å laste ned episoden/episoder, scriptet vil selv laste ned youtube-dl.exe filen som den trenger.

`./nrk-dl.ps1 [-Name] <program> [-DropSubtitles] [-DropVideo] [-DropImages] [-LegacyFormatting]`

### Eksempel

```
https://tv.nrk.no/serie/fleksnes
https://tv.nrk.no/program/KOID20001420
```

`./nrk-dl.ps1 "fleksnes"`
Scriptet vil laste ned alle episodene av Fleksnes

`./nrk-dl.ps1 "KOID20001420"`
Scriptet vil laste ned programmet

<br>

## Linux

### Dependencies

Dette vil automatisk bli lastet ned når du kjører scriptet (Støtter Debian-baserte, Arch-baserte distroer og CentOS for øyeblikket)

- youtube-dl - Denne pakken gjør at man kan laste ned videofilen fra NRK sine servere
 - curl - Denne pakken trenger man for å kunne kommunisere med NRK sitt API
 - jq - Denne pakken brukes til å hente ut informasjon fra responsen til NRK sitt api
 - screen - Denne pakken brukes når man laster ned parallellt

### Start

Scriptet kan startes med å bare kjøre det, eller legge til flere parametere i kommandoen slik at man kjappere kan laste ned flere serier/programmer.
`./nrk-dl.sh`

:warning: Ikke start scriptet med `sh nrk-dl.sh`, da vil det oppstå feil :warning:

### Parametere

- Kjøre det parallellt: (0/1)
- Hvor mange nedlastninger skal kjøre samtidig: (2-99)
- Program: (program)

`./nrk-dl.sh "<0/1>" "<2-99>" "<program>"`


### Eksempel

`./nrk-dl.sh "1" "5" "fleksnes"`

Nedlastningen vil kjøre parallellt med 5 samtidige nedlastninger av Fleksnes

<br>

`./nrk-dl.sh "0" "" "fleksnes"`

Nedlastningen av Fleksnes vil kjøre serielt (laste ned en video om gangen)
