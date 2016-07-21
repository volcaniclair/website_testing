#!/bin/bash

# getURL.sh
# ---------

URL=${1}
WORKINGDIR=${2}
THRESHOLD=${3}
TYPE=${4}

HOSTNAME=$( echo "${URL}" | awk -F"/" '{ print $3 }' )
IP=$( ping -c 1 -W 1 ${HOSTNAME} | head -n 1 | awk -F"(" '{ print $2 }' | awk -F")" '{ print $1 }' )
	
URLSTARTTIME=$( date +%s )
HTTPCODE=$( curl ${TYPE} --insecure --location --output /dev/null --silent --write-out '%{http_code}' ${URL} )
URLENDTIME=$( date +%s )
let 'URLTOTALTIME=URLENDTIME-URLSTARTTIME'
OUTPUT="${IP} - ${URL} - ${URLTOTALTIME} secs - ${HTTPCODE}"
if [ ${HTTPCODE} -ne 200 ]
then
	echo ${OUTPUT} >> ${WORKINGDIR}/errorurls
else
	echo ${OUTPUT} >> ${WORKINGDIR}/processedurls
	if [ ${URLTOTALTIME} -gt ${THRESHOLD} ]
	then
		echo ${OUTPUT} >> ${WORKINGDIR}/slowurls
	fi
fi
