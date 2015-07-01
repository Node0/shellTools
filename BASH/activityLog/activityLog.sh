#!/bin/env bash

# Notice
# ----------------------------------------------------------------
# Copyright (C) 2015  Joe J Hacobian
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version, a copy of the GNU GPL (version 3)
# is included in the root directory of this repository in a file named
# LICENSE.TXT, please review it for further details.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# General Information
# ----------------------------------------------------------------
# Name: activityLog.sh
# Version: v0.1
# Release: Development
# Author: Joe Hacobian
# Usage: Run without parameters for usage info.
# Description: Creates a general 'timeslice' snapshot of activity
# on a server and saves that data to a compressed plain text log file.
# This script is designed to be triggered from a cron job at fairly frequent
# intervals (1 to 5 minutes typically). The filename of each such activity
# log file contains the load average, day of week, year, month, & day of month.
#
# Metrics Measured in this version:
#
# *(top) Process list with CPU & RAM consumption,
#   formatted per cpu, with relative memory size units (MB & GB).
#
# *(netstat) Thoroughput on network interfaces
# *(netstat) Daemons and open ports list
# *(netstat) Network connections
# *(MySQL) 60 high-freqeuency samples of active queries
#   running on the server during the activity log window (timeslice).



### Disclaimer
### --------------------------------------------------------------
### This script and all accompanying configuration, directive, executable, and
### log files together with the directory structures, and other miscellanious files
### necessary for the proper operation of the same hereinafter will be referred to
### as "the software".
### By acknowledging the presence of this software on your computing infrastructure
### and by not removing it or otherwise hindering its normal operation, you agree to
### to assume all responsibility for the consequences of enabling, continuing to run,
### or otherwise operating this software, in addition to this you also agree to
### indemnify and hold the author(s) harmless against any  possible damages
### either resulting from running this software as is or damages resulting
### from your own modification and subsequent execution of the software.
### If you do not agree with the terms of this disclaimer, please promptly
### terminate the execution or scheduled execution of this software; please also
### promptly uninstall, or remove this software from your computing infrastructure.


function processParams {
    # Parameter Regexes
    # Note: Regexes structured with regard for parameter-case
    # in order to ensure smooth interchangability between grep and sed
    # without regard to version (of sed) or system. Per-tool case
    # sensitivity flags 'may' have otherwise resulted in more brittle code.

    epochParam="\-\-[eE][pP][oO][cC][hH]";
    ipAddrRgx="\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b";

    # Out of order parameter processing loop (script may be invoked with params given in any order)
    paramList=("${@}");
    for param in "${paramList[@]}";
    do
        # In general: Detect presence of parameter i.e. ( $(echo ${param} | grep -Po) != "" )
        # then handle the particulars using sed for access if the param is a key:value pair.

        #Handle Filename epoch prefix parameter check
        if [[ "$(echo "${param}" |command grep -Po '('${epochParam}')')" != "" ]]; then
            FilenameEpochPrefix="1";
        else
            FilenameEpochPrefix="0";
        fi
    done;
}
processParams "${@}";

# Cronification variables
# Todo: Wrap this in a function and test for presence of the commands.
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
# Todo: Re-think this to handle both automatic (cron-triggered) mode
# as well as an interactively called (by the user) mode. When run interactively
# by the user, activityLog should place the log file in the same directory
# the script itself.
actLogDir="activityLog"
centOsVer=$(cat /etc/redhat-release | sed -r 's~(^.+release)(.+)([0-9]\.[0-9]{1,})(.+$)~\3~g');


#Grab a timeslice of system activity

function dateString {
    if [[ $1 == "" ]]; then
        dateStrng=$(command date +'%a %m-%d-%Y at %k%Mh %Ss' |command sed -r "s~(\s)~_~g" |command sed -r "s~(__)~_~g" );
        echo "${dateStrng}";
    fi
    if [[ $1 == "epoch" ]]; then
        dateStrng=$(command date +'%s' );
        echo "${dateStrng}";
    fi
    if [[ $1 == "hcode" ]]; then
        dateStrng=$(command date +'%a %m-%d-%Y at %k%Mh %Ss' |command sed -r "s~(\s)~_~g" |command sed -r "s~(__)~_~g" );
        hashCode=$(command date +'%N' |md5sum |cut -b 1,3,5,7,9);
        echo ""${dateStrng}"-"${hashCode}"";
    fi
}


cd ~


# Todo: Complete the task this started by restoring found .toprc files (if any) after activityLog completes its run.
if [[ -f ~/.toprc ]];
then
    mv ~/.toprc ~/.backup_toprc
fi

echo "RCfile for \"top with windows\"
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

if [[ "${FilenameEpochPrefix}" == "1" ]];
then
    thisSliceEpoch=$(dateString epoch);
    logFileName="${thisSliceEpoch}-load_avg_${uptimeLabel}__at_${thisSlice}.log";
elif [[ "${FilenameEpochPrefix}" == "0" ]];
then
    logFileName="load_avg_${uptimeLabel}__at_${thisSlice}.log";
fi

# Todo: All of this needs to be cleaned up and wrapped into discrete funtions.
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

# Todo: MySQL access needs to be more systematically tested and lack of access handled gracefully.
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


# Todo: The '--transform' parameter is not portable across linux distributions (recently issues with RedHat to Debian compatibility)
# Look more carefully into this.
# Run tar with the apropriate options (or lack thereof) for the version of CentOS we're on.
if (( "${centOsVer:0:1}" == '6' ));
then
    ${tar} --transform 's/.*\///g' -czf ~/${actLogDir}/${logFileName}.tar.gz ~/${actLogDir}/${logFileName};
elif (( "${centOsVer:0:1}" == '5' ));
then
    ${tar}  -czf ~/${actLogDir}/${logFileName}.tar.gz ~/${actLogDir}/${logFileName};
fi

# If the tarball was created, then remove the uncompressed log file.
if [[ -f ~/${actLogDir}/${logFileName}.tar.gz ]];
then
    ${rm} -f ~/${actLogDir}/${logFileName};
fi
