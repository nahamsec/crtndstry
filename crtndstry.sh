#!/usr/bin/env bash

# This was created during a live stream on 11/16/2019
# twitch.tv/nahamsec
# Thank you to nukedx and dmfroberson for helping debug/improve

if [ ! -x "$(command -v jq)" ]; then
	echo "[-] This script requires jq. Exiting."
	exit 1
fi

certdata(){
	#give it patterns to look for within crt.sh for example %api%.site.com
	declare -a arr=("api" "corp" "dev" "uat" "test" "stag" "sandbox" "prod" "internal")
	for i in "${arr[@]}"
	do
		#get a list of domains based on our patterns in the array
		crtsh=$(curl -s https://crt.sh/\?q\=%25$i%25.$1\&output\=json | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a rawdata/$1-crtsh.txt )
	done
		#get a list of domains from certspotter
		certspotter=$(curl -s https://certspotter.com/api/v0/certs\?domain\=$1 | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep -w $1\$ | tee rawdata/$1-certspotter.txt)
		#get a list of domains from digicert
		digicert=$(curl -s https://ssltools.digicert.com/chainTester/webservice/ctsearch/search?keyword=$1 -o rawdata/$1-digicert.json) 
		#echo "$crtsh"
		#echo "$certspotter"
		#echo "$digicert"
}


rootdomains() { #this creates a list of all unique root sub domains
	cat rawdata/$1-crtsh.txt | rev | cut -d "."  -f 1,2,3 | sort -u | rev > ./$1-temp.txt
	cat rawdata/$1-certspotter.txt | rev | cut -d "."  -f 1,2,3 | sort -u | rev >> ./$1-temp.txt
	domain=$1
	jq -r '.data.certificateDetail[].commonName,.data.certificateDetail[].subjectAlternativeNames[]' rawdata/$1-digicert.json | sed 's/"//g' | grep -w "$domain$" | grep -v '^*.' | rev | cut -d "."  -f 1,2,3 | sort -u | rev >> ./$1-temp.txt
	cat $1-temp.txt | tr '[:upper:]' '[:lower:]' | sort -u | tee ./data/$1-$(date "+%Y.%m.%d-%H.%M").txt; rm $1-temp.txt
	echo "[+] Number of domains found: $(cat ./data/$1-$(date "+%Y.%m.%d-%H.%M").txt | wc -l)"
}


certdata $1
rootdomains $1
