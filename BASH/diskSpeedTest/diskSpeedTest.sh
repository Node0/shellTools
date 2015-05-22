#!/bin/bash

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
# Name: diskSpeedTest.sh
# Version: v0.1
# Release: Stable
# Author: Joe Hacobian
# Usage: No usage information available, simply run script on target storage device
#        for detailed storage throughput report.
#
# Description: A Simple disk speed test series using dd and some nested loops.
#              Simply copy this script to the mounted storage device you wish
#              to benchmark, and execute it. A log file will be generated.


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


dateString=$(command date +'%a %m-%d-%Y at %k%M hours' |command sed -r "s~(\s)~_~g" |command sed -r "s~(__)~_~g" );
logFile="diskSpeedTests_$dateString.log";

blockSizes=( "512" "1024" "2048" "4096" "8192" "16384" "32768" "65536" "131072" "262144" "524288" "1048576" "2097152" "4194304" "8388608" "16777216" );

counts=( "64" "128" "256" "512" "1024" );

echo -e "Preparing for Disk Speed Tests\n";
echo -e "################################################################################\n\n\n";

echo " " > ~/"${logFile}";

printf "Disk Speed Tests started on %-20s\n" "$(date +'%A %m-%d-%Y at %k%M hours')"; >> "${logFile}";

echo -e "#################################################################################\n\n\n"; >> "${logFile}";


for i in "${blockSizes[@]}";
do

        for j in "${counts[@]}";
        do

        printf "Performing test for block-size %u at %u counts on %-20s \n" "$i" "$j" "$(date +'%A %m-%d-%Y at %k%M hours')";
        echo -e "--------------------------------------------------------------------------------\n";


        if (( ${i} != "16777216" ))
        then

        printf "Performing test for block-size %u at %u counts on %-20s \n" "$i" "$j" "$(date +'%A %m-%d-%Y at %k%M hours')" >> "${logFile}";
        echo -e "--------------------------------------------------------------------------------\n\n" >> "${logFile}";
        dd bs=$i count=$j if=/dev/zero of=test conv=fdatasync 2>> "${logFile}";
        printf "\n" >> "${logFile}";

        printf "\n\n\n";

        fi

        if (( ${i} == "16777216" && ${j} <= "512"  ))
        then

        printf "Performing test for block-size %u at %u counts on %-20s \n" "$i" "$j" "$(date +'%A %m-%d-%Y at %k%M hours')" >> "${logFile}";
        echo -e "--------------------------------------------------------------------------------\n\n" >> "${logFile}";
        dd bs=$i count=$j if=/dev/zero of=test conv=fdatasync 2>> "${logFile}";
        printf "\n" >> "${logFile}";

        printf "\n\n\n";

        fi

        done;

done;