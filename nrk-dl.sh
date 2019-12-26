#!/bin/bash
parallell="$1"
threads="$2"
program="$3"
min_freespace="1048576" # 1GB er 1048576
packages="youtube-dl curl jq screen"

##### Installasjon av pakker som NRK-DL trenger for å fungere
if [ ! -f "nrk-dl-installed.txt" ]; then
    while true; do
        echo "NRK-DL krever at youtube-dl, curl, jq og screen installeres for at NRK-DL skal fungere" ""
        read -p "Ønsker du at vi gjør dette for deg automatisk [y/n/q]? " install
        case $install in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            [Qq]* ) exit;;
            * ) echo "Svar [y]es, [n]o eller [q]uit"; echo "";;
        esac
    done

    # Sjekk hvilke package managers eksisterer
    apt_path=$(command -v apt-get)
    yum_path=$(command -v yum)
    pacman_path=$(command -v pacman)

    if [ "$EUID" -ne 0 ]; then
        sudo_exist=$(command -v sudo)
        if [ "$sudo_exist" = "" ]; then
            echo "Kjører ikke som root, har heller ikke sudo installert"
            exit
        fi
        
        if [ "$apt_path" != "" ]; then
            echo "Installerer pakker for Deiban basert OS"
            sudo apt-get update
            sudo apt-get -y install $packages
        elif [ "$yum_path" != "" ]; then
            echo "Installerer pakker for CentOS"
            sudo yum -y install $packages
        elif [ "$pacman_path" != "" ]; then
            echo "Installerer pakker for Arch basert OS"
            sudo pacman -Syy
			sudo pacman -S -y $packages
        fi
    else
        if [ "$apt_path" != "" ]; then
            echo "Installerer pakker for Deiban basert OS"
            apt-get update
            apt-get -y install $packages
        elif [ "$yum_path" != "" ]; then
            echo "Installerer pakker for CentOS"
            yum -y install $packages
        elif [ "$pacman_path" != "" ]; then
            echo "Installerer pakker for Arch basert OS"
            pacman -Syy
			pacman -S -y $packages
        fi
    fi
    echo "1" > "nrk-dl-installed.txt"
fi

##### Opprette downloads mappe om den ikke finnes
if [ ! -d "downloads" ]; then
    mkdir "downloads"
    if [ ! -d "downloads" ]; then
        echo "" "Kunne ikke opprette mappe 'downloads'"
        exit
    fi
fi

##### Spørsmål om å laste ned parallellt
if [ "$parallell" != "0" ] && [ "$parallell" != "1" ]; then
    while true; do
        echo ""
        read -p "Ønsker du å laste ned parallelt [y/n/q]? (Anbefalt om du har god båndbredde på nettverket) " response_parallelt
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
            [123456789][1234567890] );;
            [23456789] );;
            * ) echo "";echo "Feil: Bruk tall fra 2 til 99"; exit;;
        esac
    fi
fi

##### Spørsmål om hvilken serie som ønskes lastet ned
if [ "$program" = "" ]; then
    while true; do
        echo "" "https://tv.nrk.no/serie/<serienavn>" ""
        read -p "Hvilken serie ønsker du å laste ned? " program

        program_check=$(curl -s "http://psapi-granitt-prod-ne.cloudapp.net/series/$program" | grep "https://tv.nrk.no/serie")
        if [ "$program_check" = "" ]; then
            echo "" "404: Finner ikke serie"
        fi
    done
else
    program_check=$(curl -s "http://psapi-granitt-prod-ne.cloudapp.net/series/$program" | grep "https://tv.nrk.no/serie")
    if [ "$program_check" = "" ]; then
        echo "" "404: Finner ikke serie"
        exit
    fi
fi

##### Opprett mappe til nedlastningen av serien
if [ ! -d "downloads/${program}" ]; then
    mkdir "downloads/${program}"
    if [ ! -d "downloads/${program}" ]; then
        echo "" "Kunne ikke opprette mappe: downloads/${program}"
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

##### Seriell nedlastning
if [ "$parallell" = "0" ]; then
    for link in ${links}
    do
        while true; do
            if [ "$cur_freespace" -gt "$min_freespace" ]; then
                progress=$(expr $progress + 1)
                printf "\n\n"
                echo "Starter nedlastning ($progress/$links_num)"
                youtube-dl "$link"
                break;
            else
                echo "Lite plass ledig, avventer til det er $(expr $min_freespace / 1048576)GB plass ledig, venter 30 sekunder..."
                sleep 30
            fi
        done
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
                    screen -r "nrk-dl-$program-$thread_num" -X stuff "youtube-dl $link"
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
    echo "" "Alle nedlastninger har staret, de kjører i bakgrunn så pass på at de får kjørt seg ferdig (screen -list)"
fi