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
# Version: v0.2
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

function showUsage {

    clear;
    echo "Usage: $(basename "$0") [-h]|[--help] [--epoch] [--sample-mysql] [--history-length=<number of days>]";
    echo "----------------------------------------------------------------";
    echo "Parameters with an asterisk are optional:";
    echo "          Help: -h or --help, shows this help page.";
    echo "         Epoch: --epoch, prefixes all snapshot filenames with the unix epoch (useful in some sorting contexts).";
    echo "      Database: --sample-mysql, if non-authenticated access to mysql is available, this parameter will cause";
    echo "                activityLog to sample mysql for 15 seconds out of each run, collecting a total of 60 snapshots of";
    echo "          	  mysql activity as revealed through the \"show full processlist\" statement.";
    echo "History Length: --history-length=<number of days>, this parameter will cause activityLog to (at run time) check the";
    echo "          	  list of snapshots for any which are older than <number of days> old, and delete those snapshots thereby";
    echo "          	  always keeping the depth (in time) of the list of snapshots at exactly the number of days indicated.";
    echo "----------------------------------------------------------------";
    echo -ne "\n";
    exit 1
}



# Cronification variables
# Todo: Wrap this in a function and test for presence of the commands.
date=$(which date);
md5sum=$(which md5sum);
cut=$(which cut);
grep=$(which grep);
awk=$(which awk);
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
mkdir=$(which mkdir);
whoami=$(which whoami);

# Set the home directory for this run as the current user's home directory
homeDirEnvBackup="${HOME}";
currentUsrHomeDir=$(${grep} -P '(^'$(${whoami})')' /etc/passwd | ${awk} 'BEGIN { FS = ":" } ; { print $6 }');
HOME="${currentUsrHomeDir}";

function processParams {
    # Parameter Regexes
    # Note: Regexes structured with regard for parameter-case
    # in order to ensure smooth interchangability between grep and sed
    # without regard to version (of sed) or system. Per-tool case
    # sensitivity flags may have otherwise resulted in more brittle code.

    helpShort="\-[hH]";
    helpLong="\-\-[Hh][Ee][Ll][Pp]";
    epochParam="\-\-[Ee][Pp][Oo][Cc][Hh]";
    mysqlParam="\-\-[Ss][Aa][Mm][Pp][Ll][Ee]\-[Mm][Yy][Ss][Qq][Ll]";
    fsRwRoParam="\-\-[Ss][Hh][Oo][Ww][Rr][Oo][Oo][Tt][Ff][Ss][Ss][Tt][Aa][Tt][Ee]";
    historyLength="\-\-[Hh][Ii][Ss][Tt][Oo][Rr][Yy]\-[Ll][Ee][Gg][Nn][Tt][Hh]\=";
    ipAddrRgx="\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b";

    # Out of order parameter processing loop (script may be invoked with params given in any order)
    paramList=("${@}");
    for param in "${paramList[@]}";
    do
        # In general: Detect presence of parameter i.e. ( $(echo ${param} | grep -Po) != "" )
        # then handle the particulars using sed for access if the param is a key:value pair.

        # Handle help flag detectin and display usage info / help message.
        if [[ "$(echo "${param}" |command grep -Po '('${helpShort}')' )" != "" ]]; then
        histLength=$(echo "${param}" |command sed -r "s~(${helpShort})~~g");
        showHelp=1;
        fi
        if [[ "$(echo "${param}" |command grep -Po '('${helpLong}')' )" != "" ]]; then
        histLength=$(echo "${param}" |command sed -r "s~(${helpLong})~~g");
        showHelp=1;
        fi


        # Handle activityLog history length
        if [[ "$(echo "${param}" |command grep -Po '('${historyLength}')' )" != "" ]]; then
        histLength=$(echo "${param}" |command sed -r "s~(${historyLength})~~g");
        finiteHistory=1;
        fi


        # Handle Filename epoch prefix parameter check
        if [[ "$(echo "${param}" |command grep -Po '('${epochParam}')')" != "" ]]; then
            filenameEpochPrefix=1;
        # For some reason the else clause below has always been triggered, even when
        # the initial test was true setting the first clause to run.
        # else
        #   filenameEpochPrefix=0;
        fi

        # Handle Root Filesystem Read/Write or Read-Only state check param
        if [[ "$(echo "${param}" |command grep -Po '('${fsRwRoParam}')')" != "" ]]; then
            runRootFsStateCheck=1;
        fi

        # Sample Mysql processlist
        if [[ "$(echo "${param}" |command grep -Po '('${mysqlParam}')')" != "" ]]; then
            sampleMySQL=1;
        else
            sampleMySQL=0;
        fi

    done;
}
processParams "${@}";

if [[ "${showHelp}" == 1 ]]; then
showUsage;
fi

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


function rootFsRwRoStateCheck {

# Test if the root filesystem has been mounted Read/Write or Read-Only
if [[ $(mount | grep -Pi "^(.+on)(\s{1,})(\/\s)" | grep -Pio "(rw)")  == "rw" ]]; then
mountRwFlag=1;
else
mountRwFlag=0;
fi

# Test if we can actually write to a file (in the filesystem root directory).
cd /
testFile="filesystemReadWriteTestFile.txt";
touch ${testFile};
echo "Test File Contents" >> ${testFile};

if [[ -f ${testFile} ]]; then
fileWriteTest=1;
else
fileWriteTest=0;
fi

rm -f ${testFile};
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

if (( filenameEpochPrefix == 1 ));
then
    # Generate the date-string as a unix epoch
    thisSliceEpoch=$(dateString epoch);

    # If enabled, run the root filesystem check and alter the filename accordingly
    if (( runRootFsStateCheck == 1 )); then
    rootFsRwRoStateCheck;
        if (( mountRwFlag == 1 && fileWriteTest == 1 )); then
        logFileName="${thisSliceEpoch}-load_avg_${uptimeLabel}_fs-is-mounted-RW_at_${thisSlice}.log";
        elif (( mountRwFlag == 1 && fileWriteTest == 0 )); then
        logFileName="${thisSliceEpoch}-load_avg_${uptimeLabel}_fs-is-mounted-??_at_${thisSlice}.log";
        elif (( mountRwFlag == 0 && fileWriteTest == 1 )); then
        logFileName="${thisSliceEpoch}-load_avg_${uptimeLabel}_fs-is-mounted-??_at_${thisSlice}.log";
        elif (( mountRwFlag == 0 && fileWriteTest == 0 )); then
        logFileName="${thisSliceEpoch}-load_avg_${uptimeLabel}_fs-is-mounted-RO_at_${thisSlice}.log";
        fi
    else
    logFileName="${thisSliceEpoch}-load_avg_${uptimeLabel}__at_${thisSlice}.log";
    fi

elif (( filenameEpochPrefix == 0 )); then

    # If enabled, run the root filesystem check and alter the filename accordingly
    if (( runRootFsStateCheck == 1 )); then
    rootFsRwRoStateCheck;
        if (( mountRwFlag == 1 && fileWriteTest == 1 )); then
        logFileName="load_avg_${uptimeLabel}_fs-is-mounted-RW_at_${thisSlice}.log";
        elif (( mountRwFlag == 1 && fileWriteTest == 0 )); then
        logFileName="load_avg_${uptimeLabel}_fs-is-mounted-??_at_${thisSlice}.log";
        elif (( mountRwFlag == 0 && fileWriteTest == 1 )); then
        logFileName="load_avg_${uptimeLabel}_fs-is-mounted-??_at_${thisSlice}.log";
        elif (( mountRwFlag == 0 && fileWriteTest == 0 )); then
        logFileName="load_avg_${uptimeLabel}_fs-is-mounted-RO_at_${thisSlice}.log";
        fi
    else
    logFileName="load_avg_${uptimeLabel}__at_${thisSlice}.log";
    fi
fi

# Todo: All of this needs to be cleaned up and wrapped into discrete funtions.
if [[ ! -d ~/${actLogDir} ]]; then ${mkdir} ~/${actLogDir}; fi
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
if [[ "${sampleMySQL}" == "1" ]];
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

# Set the environment variables
# that we've changed back to how
# we found them before this script ran.
HOME="${homeDirEnvBackup}";