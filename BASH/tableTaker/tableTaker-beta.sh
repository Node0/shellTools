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

# Name: TableTaker.sh
# Description: Dump MySQL table data into separate SQL files for a specified database.
# Usage: Run without args for usage info.
# Author: @JoeHacobian
# Notes:
#  * Script will prompt for password for db access.
#  * Output files are compressed and saved in the current working dir, unless DIR is
#    specified on command-line.


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
    echo "Usage: $(basename "$0") [--host=foo] [--user=bar or --user=none ] [--database=bat] [--outputdir=baz] [--compress or --nocompress]";
    echo "Note: The output directory is optional, as is compression. Un-compressed SQL output is default behavior.";
    exit 1
fi


function processParams {

    #Shove all params into an array and loop through it to process them
    argv=("${@}");
    for param in "${argv[@]}";
    do

    # In general: Detect presence of parameter first i.e. ( $(echo ${param} | grep -Pic) > 0 )
    # then handle the particulars using sed for access if the param is a key:value pair.

    #Handle db host parameter
    setHost=$(echo "${param}" | command grep -Pic "\-\-host\=");
    if [[ "${setHost}" > 0 ]]; then
        setHostString=$(echo "${param}" |command sed -r "s~(\-\-host\=)~~g");
        #TODO Handle edge cases where --host is given but empty i.e. --host=
        dbHost="${setHostString}";
    fi

    #Handle db user parameter
    setDbUser=$(echo "${param}" | command grep -Pic "\-\-user\=");
    if [[ "${setDbUser}" > 0 ]]; then
        setDbUserString=$(echo "${param}" |command sed -r "s~(\-\-user\=)~~g");
        #TODO Handle edge cases where --user is given but empty i.e. --user=
        dbUser="${setDbUserString}";
    fi

    #Handle db parameter
    setDb=$(echo "${param}" | command grep -Pic "\-\-database\=");
    if [[ "${setDb}" > 0 ]]; then
        setDbString=$(echo "${param}" |command sed -r "s~(\-\-database\=)~~g");
        #TODO Handle edge cases where --database is given but empty i.e. --database=
        DB="${setDbString}";
    fi

    #Handle output directory parameter
    setOutputDir=$(echo "${param}" | command grep -Pic "\-\-outputdir\=");
    if [[ "${setOutputDir}" > 0 ]]; then
        outputDirString=$(echo "${param}" |command sed -r "s~(\-\-outputdir\=)~~g");
        #TODO Handle edge cases where --outputdir is given but empty i.e. --outputdir=
        outputDir="${outputDirString}";
    fi

    #Handle compression parameter
    setCmpressTest=$(echo "${param}" | command grep -Pic "\-\-compress");
    if [[ "${setCmpressTest}" > 0 ]]; then
        setCompress="1";
    fi
done;
}
processParams;

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
    outputDir="${DB}_Exported_on_${thisRunTimeStamp}";
    mkdir "${outputDir}";
}

function makeCustomOutputDir {
    mkdir "${outputDir}";
}


function checkAndReport {
    chkOutputDir=$(command ls ${outputDir} |command grep -Pic ".");
    if [[ ${chkOutputDir} == 0 ]]; then
        echo -ne "\n\n\n";
        echo "ATTENTION!! Something went wrong with the export, ${chkOutputDir} tables were exported.";
        echo "Please check your database access credentials and try again.";
        rm -rf "${outputDir}";
        rm -f "${outputDir}"_db_export_log.txt;
    else
        echo -ne "\n\n\n";
        echo "EXPORT COMPLETE.";
        echo "${tbl_count} tables dumped from database ${DB} into dir=${outputDir}";
    fi
}

if [[ ${outputDir} != "" ]]; then

    if [[ ! -d ${outputDir} ]]; then
        echo "Custom output Directory specified.";
        echo "Tables will be exported to: ${outputDir}";
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
            rm -rf "${outputDir}";
        makeCustomOutputDir;
        fi

        if [[ "$outputDirDecision" == "no" ]]; then
        makeDfltOutputDir;
        fi
    fi
fi

if [[ "${outputDir}" == "" ]]; then
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

echo "Please enter the password for the mysql user: ${dbUser}";
echo "${dbUser}'s password: "
read -s DB_pass;
echo "Dumping tables into separate SQL command files for database '${DB}' into dir=${outputDir}"

echo "Log of Table Taker activity as initiated on $(date +'%A %m-%d-%Y at %k%M hours')" |command tee "${outputDir}"_db_export_log.txt
printf "\n\n\n" >> "${outputDir}"_db_export_log.txt

#Get number of tables in Database for running log
tablesInDB=$(mysql -NBA -h "${dbHost}" -u "${dbUser}" -p"${DB_pass}" -D "${DB}" -e 'show tables' |command grep -c .)

tbl_count=0

for currentTable in $(mysql -NBA -h "${dbHost}" -u "${dbUser}" -p"${DB_pass}" -D "${DB}" -e 'show tables')
do
    #Append current status into a log file for reference.
    printf "DUMPING TABLE #:%u of %u, %-50s on %-20s \n" "$tbl_count" "$tablesInDB" "${currentTable}" "$(date +'%A %m-%d-%Y at %k%M hours')" >> "${outputDir}"_db_export_log.txt

    #Display output to screen for monitoring.
    printf "DUMPING TABLE #:%u of %u, %-50s on %-20s \n" "$tbl_count" "$tablesInDB" "${currentTable}" "$(date +'%A %m-%d-%Y at %k%M hours')"

    #Export the table, and if specified, compress it.
    if [ "${setCompress}" == "1" ]; then
        mysqldump -h "${dbHost}" -u "${dbUser}" -p"${DB_pass}" "${DB}" "${currentTable}" |command gzip > "${outputDir}"/"${currentTable}".sql.gz
    else
        mysqldump -h "${dbHost}" -u "${dbUser}" -p"${DB_pass}" "${DB}" "${currentTable}" > "${outputDir}"/"${currentTable}".sql
    fi

    (( tbl_count++ ))
done
checkAndReport;