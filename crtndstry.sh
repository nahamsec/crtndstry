# This was created during a live stream on 11/16/2019
# twitch.tv/nahamsec
# Thank you to nukedx and dmfroberson for helping debug/improve

digi()
{
	RES=`curl "https://ssltools.digicert.com/chainTester/webservice/ctsearch/search?keyword=$1" -s -k`
	echo $RES > rawdata/digicert.json
	# retry if the 404 shows up, fixes https://github.com/nahamsec/crtndstry/issues/3
	if [[ $RES =~ "DOCTYPE" ]]; then
		sleep 0.5
		RES=`digi $1`
	fi
	echo $RES | jq -r '.data.certificateDetail[].commonName,.data.certificateDetail[].subjectAlternativeNames[]' | grep -w "$1\$" | grep -v '*' | grep -v "^$1\$" | sort -u || '' # || '' handles empty responses
}


certdata(){
	#give it patterns to look for within crt.sh for example %api%.site.com
	declare -a arr=("api" "corp" "dev" "uat" "test" "stage" "sandbox" "prod" "internal")
	for i in "${arr[@]}"; do
		#get a list of domains based on our patterns in the array
		sub="${i}.$1"
		url="https://crt.sh/?q=${sub}&output=json"
		crtsh=`curl -s "${url}"`
		crtsh=`echo ${crtsh} | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a rawdata/crtsh.txt || ''`
	done
		#get a list of domains from certspotter
		certspotter=$(curl -s https://certspotter.com/api/v0/certs\?domain\=$1 | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep -w $1\$ | tee rawdata/certspotter.txt)
		#get a list of domains from digicert
		digicert=$(digi $1) 
		echo "$crtsh"
		echo "$certspotter" 
		echo "$digicert" 
}



rootdomains() { #this creates a list of all unique root sub domains
	clear
	echo "working on data"
	cat rawdata/crtsh.txt | rev | cut -d "."  -f 1,2,3 | sort -u | rev | tee ./$1-temp.txt
	cat rawdata/certspotter.txt | rev | cut -d "."  -f 1,2,3 | sort -u | rev | tee -a ./$1-temp.txt
	domain=$1
	jq -r '.data.certificateDetail[].commonName,.data.certificateDetail[].subjectAlternativeNames[]' rawdata/digicert.json | sed 's/"//g' | grep -w "$domain$" | rev | cut -d "."  -f 1,2,3 | sort -u | rev | tee -a ./$1-temp.txt
	cat $1-temp.txt | sort -u | tee ./data/$1-$(date "+%Y.%m.%d-%H.%M").txt; rm $1-temp.txt
	echo "Number of domains found: $(cat ./data/$1-$(date "+%Y.%m.%d-%H.%M").txt | wc -l)" 
}

certdata $1
rootdomains $1
