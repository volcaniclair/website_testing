#!/bin/bash

# webtest.sh
# ------------
# Tests all URLs contained in sitemap.xml downloaded from https://<HOST>/sitemap.xml

##### START FUNCTIONS #####

function getOptions {
        MATCH='*--*) #*'
        COUNT=0
        DESCRIPTION=()
        OPTS=""
        for LINE in $( cat ${0} )
        do
                if [[ ${LINE} == ${MATCH} ]]
                then
                        if [[ ${LINE} == *MATCH* ]]
                        then
                                continue
                        fi
                        SHORTOPT=$( echo ${LINE} | awk -F" " '{ print $1 }' | awk -F"|" '{ print $1 }' | sed -e 's/\"//g' )
                        LONGOPT=$( echo ${LINE} | awk -F" " '{ print $1 }' | awk -F"|" '{ print $2 }' | sed -e 's/\"//g' | sed -e 's/)//g' )
                        COMMENT=$( echo ${LINE} | awk -F"#" '{ print $2 }' | sed -e 's/^ *//' )

                        if [ ${COUNT} -eq 0 ]
                        then
                                OPTS="${SHORTOPT}"
                        else
                                OPTS="${OPTS} ${SHORTOPT}"
                        fi

                        DESCRIPTION+=( "${SHORTOPT},${LONGOPT} - ${COMMENT}" )
                        let 'COUNT+=1'
                fi
        done
}

function usage {
		IFS=$'\n'
        echo
        echo " ----------"
        echo " ${0}"
        echo " -----"
        echo
        echo " Downloads sitemap.xml from target host and tests all URLs contained within it"
        echo " ----------"
		echo
		getOptions
        echo " USAGE: ${0} ${OPTS}"
        echo
        echo " OPTIONS:"
        for ITEM in ${DESCRIPTION[@]}
        do
                echo -en "    ${ITEM}\n"
        done
        echo
        exit 0
}

# Setup IFS for parsing XML
function read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

##### START #####
STARTTIME=$( date +%s )
STARTTIMEPRETTY=$( date "+%Y/%m/%d %H:%M:%S" )
STARTTIMEFOLDER=$( date "+%Y-%m-%d_%H-%M-%S" )

DISPLAY=0
while [ ${#} -gt 0 ]
do
	case ${1} in
	    "-d"|"--display") # cat slowurl and errorurl files to the command line (If they exist)
			DISPLAY=1
			;;
		"-h"|"--host") # REQUIRED: Host to test
			HOST=${2}
			shift
			;;
		"-o"|"--only-headers") # Only fetch headers
			TYPE="--head"
			;;
		"-p"|"--processes") # Number of processes to run (Default: 5)
			PROCESSES=${2}
			shift
			;;
		"-t"|"--threshold") # Report timings greater than threshold seconds (Default: 5)
			THRESHOLD=${2}
			shift
			;;
		"-w"|"--working-dir") # Working directory (Default: ./tmp)
			WORKINGDIR=${2}
			shift
			;;
		"-q"|"--query") # append to queries
			APPENDQUERY=${2}
			shift
			;;
	esac
	shift
done

if [ -z ${HOST} ]
then
	usage
fi

if [ -z ${PROCESSES} ]
then
	PROCESSES=5
fi
FAILSAFEPROCS=0
let 'FAILSAFEPROCS=PROCESSES+5'

if [ -z ${THRESHOLD} ]
then
	THRESHOLD=5
fi

if [ -z ${TYPE} ]
then
	TYPE="--get"
fi

if [ -z ${WORKINGDIR} ]
then
	WORKINGDIR="./tmp"
fi

if [ -z ${APPENDQUERY} ]
then
	APPENDQUERY=""
fi

echo
echo ${0}
echo
echo "Process Information"
echo "- Date: ${STARTTIMEPRETTY}"
echo "- Host: ${HOST}"
echo "- Processes: ${PROCESSES}"
echo "- Threshold: ${THRESHOLD}"
echo "- Failsafe Processes: ${FAILSAFEPROCS}"
WORKINGDIR="${WORKINGDIR}/${STARTTIMEFOLDER}"
echo "- Working Directory: ${WORKINGDIR}"
if [ ${TYPE} = '--head' ]
then
	echo "- Fetching only headers"
fi
echo

mkdir -p ${WORKINGDIR}

# Get sitemap
wget --directory-prefix=${WORKINGDIR} --no-check-certificate --quiet https://${HOST}/sitemap.xml

URLLIST="${WORKINGDIR}/${HOST}_urllist"
while read_dom; do
    if [[ $ENTITY = "loc" ]]; then
        echo $CONTENT
    fi
done < ${WORKINGDIR}/sitemap.xml > ${URLLIST}

COUNT=0
RUNNINGPROCS=$( ps auxwww | grep getURL.sh | grep -v grep | wc -l | awk -F" " '{ print $1 }' )
URLTOTAL=$( cat ${URLLIST} | wc -l | awk -F" " '{ print $1 }' )
for URL in $( cat ${URLLIST} )
do
	if [ ${RUNNINGPROCS} -eq ${FAILSAFEPROCS} ]
	then
		echo "Exiting: Too many processes running - RUNNINGPROCS: ${RUNNINGPROCS}"
		exit 0
	fi
	let 'COUNT+=1'
	./getURL.sh ${URL} ${WORKINGDIR} ${THRESHOLD} ${TYPE} ${APPENDQUERY} &
	RUNNINGPROCS=$( ps auxwww | grep getURL.sh | grep -v grep | wc -l | awk -F" " '{ print $1 }' )
	until [ ${RUNNINGPROCS} -lt ${PROCESSES} ]
	do
		RUNNINGPROCS=$( ps auxwww | grep getURL.sh | grep -v grep | wc -l | awk -F" " '{ print $1 }' )
		sleep 0.1
	done
	
	ELAPSED=0
	if [ -e ${WORKINGDIR}/processedurls ]
	then
		for VALUE in $( cat ${WORKINGDIR}/processedurls | awk -F" " '{ print $5 }' )
		do
			let 'ELAPSED+=VALUE'
		done
	fi
	echo -en "- Processes: ${RUNNINGPROCS} - Processed ${COUNT} of ${URLTOTAL} URLs (${ELAPSED} secs)\r"
done

URLTIMINGS="${WORKINGDIR}/urltimings"
cat ${WORKINGDIR}/processedurls | awk -F" " '{ print $5 }' | sort > ${URLTIMINGS}
FIRSTRUN=0
MAX=0
MIN=0
URLTIME=0
for VALUE in $( cat ${URLTIMINGS} )
do
	if [ ${FIRSTRUN} -eq 0 ]
	then
		MAX=${VALUE}
		MIN=${VALUE}
		FIRSTRUN=1
	else
		if [ ${VALUE} -gt ${MAX} ]
		then
			MAX=${VALUE}
		fi
		if [ ${VALUE} -lt ${MIN} ]
		then
			MIN=${VALUE}
		fi
	fi	
	let 'URLTIME+=VALUE'
done
echo -en "                                                     \r"
echo "Statistics"
echo "- Processed ${COUNT} URLs in ${URLTIME} secs (${WORKINGDIR}/processedurls)"

if [ -e ${WORKINGDIR}/slowurls ]
then
	SLOWNUM=$( wc -l ${WORKINGDIR}/slowurls | awk -F" " '{ print $1 }' )
	echo "- ${SLOWNUM} took longer than ${THRESHOLD} secs (${WORKINGDIR}/slowurls)"
	if [ ${DISPLAY} -eq 1 ]
	then
		echo "-----"
		cat ${WORKINGDIR}/slowurls
		echo "-----"
	fi
else
	echo "- All pages returned in less than ${THRESHOLD} secs"
fi

if [ -e ${WORKINGDIR}/errorurls ]
then
	ERRORNUM=$( wc -l ${WORKINGDIR}/errorurls | awk -F" " '{ print $1 }' )
	echo "- ${ERRORNUM} URLs did not return 200 (${WORKINGDIR}/errorurls)"
	if [ ${DISPLAY} -eq 1 ]
	then
		echo "-----"
		cat ${WORKINGDIR}/errorurls
		echo "-----"
	fi
else
	echo "- All pages retrieved successfully"
fi
echo

TOTALVALUES=$( wc -l ${URLTIMINGS} | awk -F" " '{ print $1 }' )
# Mean
let 'MEAN=URLTIME/TOTALVALUES'
AMOUNT=$( cat ${URLTIMINGS} | sort | uniq -c | sort -k 2 | grep -E '[0-9]* '${MEAN}'$' | awk -F" " '{ print $1 }' )
echo "- Mean: ${MEAN} secs (${AMOUNT} occurrences)"

# Median
if [ ${TOTALVALUES}%2 ] # if odd, add 1
then
	let 'TOTALVALUES+=1'
fi
MEDIAN=0
let 'TMP=TOTALVALUES/2'
MEDIAN=$( tail -n+${TMP} ${URLTIMINGS} | head -n 1 )
AMOUNT=$( cat ${URLTIMINGS} | sort | uniq -c | sort -k 2 | grep -E '[0-9]* '${MEDIAN}'$' | awk -F" " '{ print $1 }' )
echo "- Median: ${MEDIAN} secs (${AMOUNT} occurrences)"

# Mode
TMP=$( cat ${URLTIMINGS} | sort | uniq -c | sort -rn | head -n 1 )
MODE=$( echo ${TMP} | awk -F" " '{ print $2 }' )
AMOUNT=$( echo ${TMP} | awk -F" " '{ print $1 }' )
echo "- Mode: ${MODE} secs (${AMOUNT} occurrences)"
AMOUNT=$( cat ${URLTIMINGS} | sort | uniq -c | sort -k 2 | grep -E '[0-9]* '${MAX}'$' | awk -F" " '{ print $1 }' )
echo "- Max: ${MAX} secs (${AMOUNT} occurrences)"
AMOUNT=$( cat ${URLTIMINGS} | sort | uniq -c | sort -k 2 | grep -E '[0-9]* '${MIN}'$' | awk -F" " '{ print $1 }' )
echo "- Min: ${MIN} secs (${AMOUNT} occurrences)"
echo

ENDTIME=$( date +%s )
let 'TOTALTIME=ENDTIME-STARTTIME'
echo "- Script runtime: ${TOTALTIME} secs"
echo
