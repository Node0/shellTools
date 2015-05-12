#!/bin/env bash


# Cronification variables
# TODO Wrap this in a function and test for presence of the commands.
date=$(which date);
md5sum=$(which md5sum);
cut=$(which cut);
grep=$(which grep);
sed=$(which sed);
cat=$(which cat);
uptime=$(which uptime);
netstat=$(which netstat);
top=$(which top);
touch=$(which touch);
mysql=$(which mysql);
sleep=$(which sleep);
gzip=$(which gzip);
tar=$(which tar);
rm=$(which rm);

# Log Directory
actLogDir="activityLog"



#Grab a timeslice of system activity

function dateString {

if [[ $1 == "" ]]; then
dateStrng=$(command date +'%a %m-%d-%Y at %k%Mh %Ss' |command sed -r "s~(\s)~_~g" |command sed -r "s~(__)~_~g" );
echo "${dateStrng}";
fi

if [[ $1 == "hcode" ]]; then
dateStrng=$(command date +'%a %m-%d-%Y at %k%Mh %Ss' |command sed -r "s~(\s)~_~g" |command sed -r "s~(__)~_~g" );
hashCode=$(command date +'%N' |md5sum |cut -b 1,3,5,7,9);
echo ""${dateStrng}"-"${hashCode}"";
fi
}


cd ~


if [[ -f ~/.toprc ]];
        then
mv ~/.toprc ~/.backup_toprc
fi

echo "RCfile for \"top with windows\"           # shameless braggin'
Id:a, Mode_altscr=0, Mode_irixps=1, Delay_time=3.000, Curwin=0
Def     fieldscur=AEHIOQTWKNMbcdfgjplrsuvyzX
        winflags=30137, sortindx=10, maxtasks=0
        summclr=1, msgsclr=1, headclr=3, taskclr=1
Job     fieldscur=ABcefgjlrstuvyzMKNHIWOPQDX
        winflags=62777, sortindx=0, maxtasks=0
        summclr=6, msgsclr=6, headclr=7, taskclr=6
Mem     fieldscur=ANOPQRSTUVbcdefgjlmyzWHIKX
        winflags=62777, sortindx=13, maxtasks=0
        summclr=5, msgsclr=5, headclr=4, taskclr=5
Usr     fieldscur=ABDECGfhijlopqrstuvyzMKNWX
        winflags=62777, sortindx=4, maxtasks=0
        summclr=3, msgsclr=3, headclr=2, taskclr=3" > ~/.toprc;

function uptimeString {
${uptime} |\
${grep} -Pio "average\:(\s\d{1,}\.\d{1,}\,){1,}(\s\d{1,}\.\d{1,})" |\
${sed} -r "s~(average\:\s)~~g" |\
${sed} -r "s~\,~~g"|\
${sed} -r "s~\s~__~g"
}

uptimeLabel=$(uptimeString);
thisSlice=$(dateString);
logFileName="load_of__${uptimeLabel}__at_${thisSlice}.log"

${touch} ~/${actLogDir}/${logFileName};
${top} -b -M -H -n1 >>  ~/${actLogDir}/${logFileName};
echo -ne "\n\n\n\n\n\n\n" >> ~/${actLogDir}/${logFileName};
echo -ne "Thoroughput on NetWork Interfaces:\n" >> ~/${actLogDir}/${logFileName};
${netstat} -i >> ~/${actLogDir}/${logFileName};
echo -ne "\n\n" >> ~/${actLogDir}/${logFileName};
echo -ne "Daemons and Open Ports list:\n" >> ~/${actLogDir}/${logFileName};
${netstat} -plunt >> ~/${actLogDir}/${logFileName};
echo -ne "\n\n" >> ~/${actLogDir}/${logFileName};
echo -ne "Network Connections:\n" >> ~/${actLogDir}/${logFileName};
${netstat} >> ~/${actLogDir}/${logFileName};

echo -ne "\n\n\n\n\n" >> ~/${actLogDir}/${logFileName};

if [[ "${1}" == "--and-mysql" ]];
	then
echo -ne "MySQL Queries Active at ${thisSlice}\n" >> ~/${actLogDir}/${logFileName};

for i in {1..60}; do

echo -ne "\n" >> ~/${actLogDir}/${logFileName};
${mysql} --execute "show full processlist;" >> ~/${actLogDir}/${logFileName};
echo -ne "\n\n" >> ~/${actLogDir}/${logFileName};
${sleep} 0.25;
done;

fi

${tar} --transform 's/.*\///g' -czf ~/${actLogDir}/${logFileName}.tar.gz ~/${actLogDir}/${logFileName};
${rm} -f ~/${actLogDir}/${logFileName};