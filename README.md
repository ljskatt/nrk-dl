# NRK-DL

Dette prosjektet ble startet etter at det ble kjent at NRK innhold fra før 1997 kan bli borte fra NRK om det ikke kommer en ny avtale på plass med Norwaco, derfor bestemte jeg meg for å lage et script som gjør at man lett kan laste ned innehold fra NRK, slik at man kan holde på denne arven.

## Windows

### Dependencies

Dette vil automatisk bli lastet ned når du kjører scriptet

- youtube-dl.exe - Denne pakken gjør at man kan laste ned videofilen fra NRK sine servere

### Start

Last ned filen og kjør kommandoen for å begynne å laste ned episoder, scriptet vil selv laste ned youtube-dl.exe filen som den trenger

`./nrk-dl.ps1 "<program>"`

### Eksempel

`./nrk-dl.ps1 "fleksnes"`

Scriptet vil da laste ned alle episodene av Fleksnes som er tilgjengelig på NRK sine servere

<br>

## Linux (Debian, Ubuntu)

### Dependencies

Dette vil automatisk bli lastet ned når du kjører scriptet (Støtter bare Debian og Ubuntu for øyeblikket)

- youtube-dl - Denne pakken gjør at man kan laste ned videofilen fra NRK sine servere
 - curl - Denne pakken trenger man for å kunne kommunisere med NRK sitt API
 - jq - Denne pakken brukes til å hente ut informasjon fra responsen til NRK sitt api
 - screen - Denne pakken brukes når man laster ned parallellt

### Start

Scriptet kan startes med å bare kjøre det, eller legge til flere parametere i kommandoen slik at man kjappere kan laste ned flere serier/programmer.
`./nrk-dl.sh`

:warning: Ikke start scriptet med `sh nrk-dl.sh`, da vil det oppstå feil :warning:

### Parametere

- Begrenset hastighet: (0/1)
- Maks hastighet: (Tall fra 1-99999, og ending B/K/M)
- Kjøre det parallellt: (0/1)
- Hvor mange nedlastninger skal kjøre samtidig: (2-99)
- Program: (program)

`./nrk-dl.sh "<0/1>" "<1-9999><b/k/m/g>" "<0/1>" "<2-99>" "<program>"`


#### Eksempel

`./nrk-dl.sh "1" "10M" "1" "5" "fleksnes"`

Nedlastningen vil da begrense hastighet med 10MB/s (80Mbit/s), og laste ned parallellt med 5 samtidige nedlastninger av Fleksnes
<br>
`./nrk-dl.sh "0" "" "0" "" "fleksnes"`

Nedlastningen vil da ikke begrense hastighet, og vil kjøre serielt (laste ned en video om gangen)