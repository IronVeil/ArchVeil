### --- FUNCTIONS ---

## Write to file
wtf () { sed -i "s|${1}=|${1}=${out}|" ./settings.sh; }


## Print
print () {
    echo
    echo $1
}


## Lowercase
lower () { out=${1,,}; }


## Input
input () {
    local inp

    # Prompt
    read -p "$1" inp

    # Lowercase it
    [[ "$2" == "1" ]] && lower $inp || out=$inp
}