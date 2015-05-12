#!/bin/env bash

# Notice
# ----------------------------------------------------------------
# Copyright (C) 2015  Joe J Hacobian
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# General Information
# ----------------------------------------------------------------
# Name: TableTaker.sh
# Version: v0.1
# Author: Joe Hacobian
# Usage: Run without parameters for usage info.
# Description: Dump MySQL table data into separate SQL files for a specified database.



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


if [[ ${#} < 3 ]]
then
    echo "Usage: $(basename "$0") <DB_HOST> <DB_USER> <DB_NAME> [--outputdir=foo] [--compress or --nocompress]";
    echo "Note: The output directory is optional, as is compression. Un-compressed SQL output is default behavior.";
    exit 1
fi

DB_host=$1
DB_user=$2
DB=$3

#Determine if we're going to compress the output
argv=("${@}");
for param in "${argv[@]}";
do
    setOutputDir=$(echo "${param}" | command grep -Pic "\-\-outputdir\=");

    if [[ "${setOutputDir}" == "1" ]]; then
        outPutDirString=$(echo "${param}" |command sed -r "s~(\-\-outputdir\=)~~g");
        OUTPUTDIR="${outPutDirString}";
    fi
done;

for param in "${argv[@]}";
do
    setCmpressTest=$(echo "${param}" | command grep -Pic "\-\-compress");
    if [[ "${setCmpressTest}" > 0 ]]; then
        setCompress="1";
    fi
done;

function dateString {

    if [[ $1 == "" ]]; then
        dateStrng=$(command date +'%a %m-%d-%Y at %k%Mh %Ss' |\
        command sed -r "s~(\s)~_~g" |\
        command sed -r "s~(__)~_~g" );
        echo "${dateStrng}";
    fi

    if [[ $1 == "hcode" ]]; then
        dateStrng=$(command date +'%a %m-%d-%Y at %k%Mh %Ss' |\
        command sed -r "s~(\s)~_~g" |\
        command sed -r "s~(__)~_~g" );
        hashCode=$(command date +'%N' |\
        command md5sum |\
        command cut -b 1,2,5,7,8,9,12,15,19);
        echo "${dateStrng}-${hashCode}";
    fi
}

function makeDfltOutputDir {
    thisRunTimeStamp=$(dateString);
    OUTPUTDIR="${DB}_Exported_on_${thisRunTimeStamp}";
    mkdir "${OUTPUTDIR}";
}

function makeCustomOutputDir {
    mkdir "${OUTPUTDIR}";
}


function checkAndReport {
    chkOutputDir=$(command ls ${OUTPUTDIR} |command grep -Pic ".");
    if [[ ${chkOutputDir} == 0 ]]; then
        echo -ne "\n\n\n";
        echo "ATTENTION!! Something went wrong with the export, ${chkOutputDir} tables were exported.";
        echo "Please check your database access credentials and try again.";
        rm -rf "${OUTPUTDIR}";
        rm -f "${OUTPUTDIR}"_db_export_log.txt;
    else
        echo -ne "\n\n\n";
        echo "EXPORT COMPLETE.";
        echo "${tbl_count} tables dumped from database ${DB} into dir=${OUTPUTDIR}";
    fi
}

if [[ ${OUTPUTDIR} != "" ]]; then

    if [[ ! -d ${OUTPUTDIR} ]]; then
        echo "Custom output Directory specified.";
        echo "Tables will be exported to: ${OUTPUTDIR}";
        makeCustomOutputDir;
    else
        echo "Output directory exists!";
        echo "Do you want to overwrite it or create a new output directory?";
        echo "To overwrite enter: yes";
        echo "To create a new directory enter: no";
        echo -ne "Enter yes or no:";
        read -s outputDirDecision;
        echo -ne "\n";
        if [[ "$outputDirDecision" == "yes" ]]; then
            rm -rf "${OUTPUTDIR}";
            makeCustomOutputDir;
        fi

        if [[ "$outputDirDecision" == "no" ]]; then
            makeDfltOutputDir;
        fi
    fi
fi

if [[ "${OUTPUTDIR}" == "" ]]; then
    makeDfltOutputDir;
    thisRunTimeStamp=$(dateString);
    echo "No output directory specified. Generating timestamped output directory.";

    for dot in {1..20}; do
        echo -ne ".";
        sleep 0.01;
    done;
    echo -ne "\n";
    echo "The output directory is: ${DB}_Exported_on_${thisRunTimeStamp}";
    echo -ne "\n\n";
fi

echo "Please enter the password for the mysql user: ${DB_user}";
echo "${DB_user}'s password: "
read -s DB_pass;
echo "Dumping tables into separate SQL command files for database '${DB}' into dir=${OUTPUTDIR}"

echo "Log of Table Taker activity as initiated on $(date +'%A %m-%d-%Y at %k%M hours')" |command tee "${OUTPUTDIR}"_db_export_log.txt
printf "\n\n\n" >> "${OUTPUTDIR}"_db_export_log.txt

#Get number of tables in Database for running log
tablesInDB=$(mysql -NBA -h "${DB_host}" -u "${DB_user}" -p"${DB_pass}" -D "${DB}" -e 'show tables' |command grep -c .)

tbl_count=0

for currentTable in $(mysql -NBA -h "${DB_host}" -u "${DB_user}" -p"${DB_pass}" -D "${DB}" -e 'show tables')
do
    #Append current status into a log file for reference.
    printf "DUMPING TABLE #:%u of %u, %-50s on %-20s \n" "$tbl_count" "$tablesInDB" "${currentTable}" "$(date +'%A %m-%d-%Y at %k%M hours')" >> "${OUTPUTDIR}"_db_export_log.txt

    #Display output to screen for monitoring.
    printf "DUMPING TABLE #:%u of %u, %-50s on %-20s \n" "$tbl_count" "$tablesInDB" "${currentTable}" "$(date +'%A %m-%d-%Y at %k%M hours')"

    #Export the table, and if specified, compress it.
    if [ "${setCompress}" == "1" ]; then
        mysqldump -h "${DB_host}" -u "${DB_user}" -p"${DB_pass}" "${DB}" "${currentTable}" |command gzip > "${OUTPUTDIR}"/"${currentTable}".sql.gz
    else
        mysqldump -h "${DB_host}" -u "${DB_user}" -p"${DB_pass}" "${DB}" "${currentTable}" > "${OUTPUTDIR}"/"${currentTable}".sql
    fi

    (( tbl_count++ ))
done
checkAndReport;