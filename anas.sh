#!/bin/bash

### requirements ###
# curl
# jq
# csvkit
### requirements ###

set -x

cartella="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# creo due cartelle "contenitore"
mkdir -p "$cartella"/regioni
mkdir -p "$cartella"/strade

rm -rf "$cartella"/regioni/*
rm -rf "$cartella"/strade/*

# scarico i file di riepilogo delle regioni
curl -sL "http://www.stradeanas.it/sites/all/modules/anas/js/anas.app.lavori_in_corso.js" | grep -Eo '("[a-zA-Z]+":{"DB":")([a-zA-Z]+)"' | sed -r 's/("[a-zA-Z]+":\{"DB":")([a-zA-Z]+)"/\2/g' | xargs -I{} sh -c 'curl -sL http://www.stradeanas.it/it/anas/app/lavori_in_corso/lavori_regione?regione="$1" | jq . >'"$cartella"'/regioni/"$1".json' -- {}

# scarico i file di dettaglio sui lavori nelle varie strade delle regioni
cd "$cartella"/regioni
for i in *.json; do
	regione=$(echo "$i" | sed 's/\.json//g')
	echo "$regione"
	<"$i" jq -r '.LIST_ROADS[][0]' |  xargs -I{} sh -c 'curl -sL "http://www.stradeanas.it/it/anas/app/lavori_in_corso/lavori_regione_strada?regione=$regione&cod_strada=$1" | jq ".[] |= . + {\"regione\": \"'"$regione"'\",\"strada\": \""$1"\"}" >'"$cartella"'/strade/'"$regione"'"_$1.json"' -- {}
done

# creo un unico file json di output
jq -s add "$cartella"/strade/*.json >"$cartella"/stradeAnas.json
# creo un unico file csv di output
<"$cartella"/stradeAnas.json in2csv -I -f json >"$cartella"/stradeAnas.csv

# faccio l'upload su data.world
source "$cartella"/config.txt
curl "https://api.data.world/v0/uploads/ondata/anas-lavori-in-corso/files" -F file=@"$cartella"/stradeAnas.csv -H "Authorization: Bearer ${DW_API_TOKEN}"

<<comment1
comment1
