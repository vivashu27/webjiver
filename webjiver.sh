#!/bin/bash

#katana 2> /dev/null
#if [ "$?" != "" ];then
 #   echo -e "\e[31mPlease Download katana first\e[0m"
  #  exit
#fi

echo "Enter the domain to scan"
read domain

echo "Enter the output file"
read output

echo -e "\e[32mFinding subdomains....\e[0m"
subfinder -silent -d $domain > d.tmp
assetfinder $domain >> d.tmp
cat d.tmp | sort | uniq > dom.tmp
rm d.tmp
amass  enum -nocolor -d $domain -o amass -silent
cat amass | awk -F "-->" '{print $3}' | grep -E -v "RIROrganization|Netblock" | cut -d "(" -f 1 | grep -v "\\s+" | sed -E 's/^\s+//g' | grep -E -v "\S+:\S+:\S+:\S+::\S+" | grep -E -v "\S+:\S+:\S+::\S+:\S+"|grep -E -v "\S+:\S+:\S+:\S+:\S+:\S+:\S+:\S+" | grep -E -v "\S+:\S+:\S+::\S+" | grep -E -v "\S+:\S+:\S+:\S+::">>dom.tmp
echo -e "\e[32mFinding open ports....\e[0m"
naabu -silent -top-ports 1000 -list dom.tmp -o ports.tmp
cat ports.tmp | sed -e "s/^/https:\/\//g" > https.tmp
cat ports.tmp | sed  -e "s/^/http:\/\//g" > http.tmp

echo -e "\e[32mChecking the connectivity....\e[0m"
while read http; do
    if [ "$(httpx --timeout 3 --no-verify $http | grep -o 'ReadTimeout')" == "" ]; then
        echo $http >> validhttp.tmp
    fi
done < http.tmp

while read https; do
    if [ "$(httpx --timeout 3 --no-verify $https | grep -o 'ReadTimeout')" == "" ]; then
        echo $https >> validhttp.tmp
    fi
done < https.tmp


echo -e "\e[32mSpidering and Finding endpoints....\e[0m"
paramspider -l dom.tmp > param.tmp
cat validhttp.tmp | hakrawler -insecure -u  > hakcraw.tmp

while read domain; do
	cat results/$domain.txt 2> /dev/null  1>> $output.tmp
done < dom.tmp

cat hakcraw.tmp >> $output.tmp
cat $output.tmp | sort | uniq > $output

echo "Saved to your output file: $output"
