#!/bin/bash
limit_speed="$1"
maxspeed="$2"
parallell="$3"
threads="$4"
program="$5"
min_freespace="1048576" # 1GB er 1048576

##### Installasjon av pakker som NRK-DL trenger for å fungere
if [ ! -f "nrk-dl-installed.txt" ]; then
    while true; do
        echo "NRK-DL krever at youtube-dl, curl, jq og screen installeres for at NRK-DL skal fungere"
        echo ""
        read -p "Ønsker du at vi gjør dette for deg automatisk [y/n/q]? " install
        case $install in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            [Qq]* ) exit;;
            * ) echo "Svar [y]es, [n]o eller [q]uit"; echo "";;
        esac
    done
    apt-get update
    apt-get -y install youtube-dl curl jq screen
    echo "1" > "nrk-dl-installed.txt"
fi

##### Opprette downloads mappe om den ikke finnes
if [ ! -d "downloads" ]; then
    mkdir "downloads"
    if [ ! -d "downloads" ]; then
        echo ""
        echo "Kunne ikke opprette mappe 'downloads'"
        exit
    fi
fi

##### Spørsmål om det er ønsket å begrense nedlastningshastighet
if [ "$limit_speed" != "0" ] && [ "$limit_speed" != "1" ]; then
    while true; do
        echo ""
        read -p "Begrense nedlastingshastighet [y/n/q]? " response_limitspeed
        case $response_limitspeed in
            [Yy]* ) limit_speed=1; break;;
            [Nn]* ) break;;
            [Qq]* ) exit;;
            * ) echo "Svar [y]es, [n]o eller [q]uit";;
        esac
    done
fi

##### Spørsmål om hvilken maksimumhastighet du ønsker å begrense nedlastningene til, ikke nødvendig om forje spørsmål var nei
if [ "$maxspeed" = "" ]; then
    if [ "$limit_speed" = 1 ]; then
        while true; do
            echo ""
            read -p "Max hastighet i bytes pr sekund, eksempler: 1M, 1.2M, 100K: " response_maxspeed
            case $response_maxspeed in
                [123456789][1234567890][1234567890][1234567890][1234567890][BbKkMmGg] ) maxspeed="$response_maxspeed";break;;
                [123456789][1234567890][1234567890][1234567890][BbKkMmGg] ) maxspeed="$response_maxspeed";break;;
                [123456789][1234567890][1234567890][BbKkMmGg] ) maxspeed="$response_maxspeed";break;;
                [123456789][1234567890][BbKkMmGg] ) maxspeed="$response_maxspeed";break;;
                [123456789][BbKkMmGg] ) maxspeed="$response_maxspeed";break;;
                * ) echo "Svar [y]es, [n]o eller [q]uit";;
            esac
        done
    else
        limit_speed="0"
    fi
else
    case $maxspeed in
        [123456789][1234567890][1234567890][1234567890][1234567890][BbKkMmGg] ) break;;
        [123456789][1234567890][1234567890][1234567890][BbKkMmGg] ) break;;
        [123456789][1234567890][1234567890][BbKkMmGg] ) break;;
        [123456789][1234567890][BbKkMmGg] ) break;;
        [123456789][BbKkMmGg] ) break;;
        * ) echo "";echo "Nedlastningshastighet mangler suffix";exit;;
    esac
fi

##### Spørsmål om å laste ned parallellt
if [ "$parallell" != "0" ] && [ "$parallell" != "1" ]; then
    while true; do
        echo ""
        read -p "Ønsker du å laste ned paralellt [y/n/q]? (Anbefalt om du har god båndbredde på nettverket) " response_parallelt
        case $response_parallelt in
            [Yy]* ) parallell=1; break;;
            [Nn]* ) parallell=0; break;;
            [Qq]* ) exit;;
            * ) echo "Svar [y]es, [n]o eller [q]uit";;
        esac
    done
fi

##### Spørsmål om hvor mange nedlastninger skal skje samtidig, bare nødvendig om forje spørsmål var ja
if [ "$parallell" != "0" ]; then
    if [ "$threads" = "" ]; then
        while true; do
            echo ""
            read -p "Hvor mange samtidige nedlastninger skal skje samtidig? " response_threads
            case $response_threads in
                [123456789][1234567890] ) threads=$response_threads; break;;
                [23456789] ) threads=$response_threads; break;;
                * ) echo "";echo "Feil: Bruk tall fra 2 til 99";;
            esac
        done
    else
        case $threads in
            [123456789][1234567890] ) break;;
            [23456789] ) break;;
            * ) echo "";echo "Feil: Bruk tall fra 2 til 99"; exit;;
        esac
    fi
fi

##### Spørsmål om hvilken serie som ønskes lastet ned
if [ "$program" = "" ]; then
    while true; do
        echo ""
        echo "https://tv.nrk.no/serie/<serienavn>"
        echo ""
        read -p "Hvilken serie ønsker du å laste ned? " program

        program_check=$(curl -s "http://psapi-granitt-prod-ne.cloudapp.net/series/$program" | grep "https://tv.nrk.no/serie")
        if [ "$program_check" = "" ]; then
            echo ""
            echo "404: Finner ikke serie"
        else
            break;
        fi
    done
else
    program_check=$(curl -s "http://psapi-granitt-prod-ne.cloudapp.net/series/$program" | grep "https://tv.nrk.no/serie")
    if [ "$program_check" = "" ]; then
        echo ""
        echo "404: Finner ikke serie"
        exit
    else
        break;
    fi
fi

##### Opprett mappe til nedlastningen av serien
if [ ! -d "downloads/${program}" ]; then
    mkdir "downloads/${program}"
    if [ ! -d "downloads/${program}" ]; then
        echo ""
        echo "Kunne ikke opprette mappe: downloads/${program}"
        exit
    fi
fi

cd "downloads/${program}"

links_raw=""

##### Hent ut linker til episodene i serien
seasons=$(curl -s http://psapi-granitt-prod-ne.cloudapp.net/series/$program | jq ".seasons" | jq ".[].id" | cut -f 2 -d '"')
for season in ${seasons}
do
    season_links=$(curl -s "http://psapi-granitt-prod-ne.cloudapp.net/series/$program/seasons/$season/Episodes" | jq '.[]._links.share.href' | cut -f 2 -d '"')
    links_raw+="$season_links"
    links_raw+=$'\n'

done
links=$(echo "$links_raw" | grep "tv.nrk.no")
links_num=$(echo "$links" | wc -l)
progress="0"
gb_freespace=

##### Seriell nedlastning
if [ "$parallell" = "0" ]; then
    for link in ${links}
    do
        if [ "$limit_speed" = "1" ]; then
            progress=$(expr $progress + 1)
            echo "Starter nedlastning ($progress/$links_num)"
            youtube-dl -r "$maxspeed" "$link"
        else
            youtube-dl "$link"
        fi
    done
fi

##### Parallell nedlastning
thread_num="0"
if [ "$parallell" = "1" ]; then
    for link in ${links}
    do
        while true; do
            sleep 0.5
            screen_rows=`screen -list | wc -l`
            screen_num=$(expr $screen_rows - 2)
            if [ "$screen_num" -ge "$threads" ]; then
                echo "Maximum threads ($screen_num/$threads), waiting"
                sleep 10
            else
                volume=$(df $(pwd) | awk '/^\/dev/ {print $1}')
                cur_freespace=$(df "$volume" | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $4 }')
                if [ "$cur_freespace" -gt "$min_freespace" ]; then
                    thread_num=$(expr $thread_num + 1)
                    screen -S "nrk-dl-$program-$thread_num" -d -m
                    sleep 0.1
                    if [ "$limit_speed" = "1" ]; then
                        screen -r "nrk-dl-$program-$thread_num" -X stuff "youtube-dl -r $maxspeed $link"
                    else
                        screen -r "nrk-dl-$program-$thread_num" -X stuff "youtube-dl $link"
                    fi
                    sleep 0.1
                    screen -r "nrk-dl-$program-$thread_num" -X stuff '\n'
                    sleep 0.1
                    screen -r "nrk-dl-$program-$thread_num" -X stuff "exit"
                    sleep 0.1
                    screen -r "nrk-dl-$program-$thread_num" -X stuff '\n'
                    progress=$(expr $progress + 1)
                    echo "Startet nedlastning ($progress/$links_num)"
                    sleep 1
                    break;
                else
                    echo "Lite plass ledig, avventer til det er $(expr $min_freespace / 1048576)GB plass ledig, venter 30 sekunder..."
                    sleep 30
                fi
            fi
        done
    done
    echo ""
    echo "Alle nedlastninger har staret, de kjører i bakgrunn så pass på at de får kjørt seg ferdig (screen -list)"
fi