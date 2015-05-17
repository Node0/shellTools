#!/bin/env bash

#Notice
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
# Version: v0.2
# Release: Development
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


function processParams {


    # Parameter Regexes
    hostParam="\-\-[hH][oO][sS][tT]\=";
    userParam="\-\-[uU][sS][eE][rR]\=";
    ipAddrRgx="\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b";
    #Shove all params into an array and loop through it to process them
    paramList=("${@}");
    for param in "${paramList[@]}";
    do

        # In general: Detect presence of parameter i.e. ( $(echo ${param} | grep -Pic) > 0 )
        # then handle the particulars using sed for access if the param is a key:value pair.

        #Handle db host parameter
        if [[ "$(echo "${param}" |command grep -Po '('${hostParam}')' )" != "" ]]; then
            if [[ "$(echo "${param}" |command sed -r "s~(${hostParam})~~g")" != "localhost" ]]; then
                if [[ "$(echo "${param}" |command grep -Po '('${ipAddrRgx}')')" != "" ]]; then
                setHostString=$(echo "${param}" |command grep -Po '('${ipAddrRgx}')');
                fi
            else
            setHostString=$(echo "${param}" |command sed -r "s~(${hostParam})~~g");
            fi
        dbHost="${setHostString}";
        fi

        #Handle db user parameter
        if [[ "$(echo "${param}" |command grep -Po '('${userParam}')' )" != "" ]]; then
            if [[ "$(echo "${param}" |command sed -r "s~(${userParam})~~g" )" != "" ]]; then
                dbAuth="1";
                setDbUserString=$(echo "${param}" |command sed -r "s~(${userParam})~~g");
                dbUser="${setDbUserString}";
            fi
        fi

        # Temporarily added to correct authentication discernment bug.
        # db user parameter handling should be properly refactored to
        # detect (and gracefully handle) the absense of a value if the
        # --user parameter is present
        if [[ "${dbUser}" == "" ]]; then
            dbAuth="0";
        fi

        #Handle db parameter
        if [[ "$(echo "${param}" |command grep -Po "\-\-[dD][aA][tT][aA][bB][aA][sS][eE]\=")" != "" ]]; then
            setDbString=$(echo "${param}" |command sed -r "s~(\-\-[dD][aA][tT][aA][bB][aA][sS][eE]\=)~~g");
            #TODO Handle edge cases where --database is given but empty i.e. --database=
            DB="${setDbString}";
        fi

        #Handle output directory parameter
        if [[ "$(echo "${param}" |command grep -Pc "\-\-[oO][uU][tT][pP][uU][tT][dD][iI][rR]\=")" > 0 ]]; then
            outputDirString=$(echo "${param}" |command sed -r "s~(\-\-[oO][uU][tT][pP][uU][tT][dD][iI][rR]\=)~~g");
            #TODO Handle edge cases where --outputdir is given but empty i.e. --outputdir=
            outputDir="${outputDirString}";
        fi

        #Handle compression parameter
        if [[ "$(echo "${param}" |command grep -Pic "\-\-[cC][oO][mM][pP][rR][eE][sS][sS]")" > 0 ]]; then
            setCompress="1";
        else
            setCompress="0";
        fi
    done;

# Some useful debugging information
# echo "dbHost: ${dbHost}";
# echo "DB: ${DB}";
# echo "dbAuth: ${dbAuth}";
# echo "dbUser: ${dbUser}";
# echo "outputDir: ${outputDir}";
# echo "Compression: ${setCompress}";

    if [[ "${dbHost}" != "" && "${DB}" != "" ]]; then
        showUsage="0";
    else
        showUsage="1";
    fi
    if [[ ${showUsage} == "1" ]]; then
        echo "Usage: $(basename "$0") [--host=foo] [--user=bar] [--database=bat] [--outputdir=baz] [--compress]";
        echo "----------------------------------------------------------------";
        echo "Parameters with an asterisk are optional:";
        echo "      Hostname: --host=localhost or --host=<IP ADDRESS> i.e. --host=xxx.xxx.xxx.xxx";
        echo " Database User: --user=<MYSQL USERNAME> or Omit this param if no authentication is needed for CLI access to MySQL.";
        echo "      Database: --database=<DATABASE NAME>";
        echo "   *Output Dir: --outputdir=<DIRECTORY NAME> Directory will be created relative to the location of this script.";
        echo "  *Compression: --compress Omit this param to forego compression of exported table SQL.";
        exit 1
    fi
}
processParams "${@}";



function dateString {

    if [[ "${1}" == "" ]]; then
        dateStrng=$(command date +'%a %m-%d-%Y at %k%Mh %Ss' |\
        command sed -r "s~(\s)~_~g" |\
        command sed -r "s~(__)~_~g" );
        echo "${dateStrng}";
    fi

    if [[ "${1}" == "hcode" ]]; then
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
        echo -ne "\n";
        echo -ne "EXPORT COMPLETE.\n\n\n";
        echo "Export Summary";
        echo "----------------------------------------------------------------"
        echo -ne "${tbl_count} tables dumped from database: ${DB}\nOutput directory: ${outputDir}\n\n\n";
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

#If a user param was specified then ask for the password
if [[ "${dbAuth}" == "1" ]]; then
    echo "Please enter the password for the mysql user: ${dbUser}";
    echo "${dbUser}'s password: "
    read -s DB_pass;
fi


echo "Dumping tables into separate SQL command files for database '${DB}' into dir=${outputDir}"

echo "Log of Table Taker activity as initiated on $(date +'%A %m-%d-%Y at %k%M hours')" |command tee "${outputDir}"_db_export_log.txt
printf "\n\n\n" >> "${outputDir}"_db_export_log.txt

#Get number of tables in Database for running log
if [[ "${dbAuth}" == "1" ]]; then
    tablesInDB=$(mysql -NBA -h "${dbHost}" -u "${dbUser}" -p"${DB_pass}" -D "${DB}" --execute='show tables;' |command grep -c .);
elif [[ "${dbAuth}" == "0" ]]; then
    tablesInDB=$(mysql -NBA -h "${dbHost}" -D "${DB}" --execute='show tables;' |command grep -c .);
fi


tbl_count=0;

if [[ "${dbAuth}" == "1" ]]; then

    for currentTable in $(mysql -NBA -h "${dbHost}" -u "${dbUser}" -p"${DB_pass}" -D "${DB}" --execute='show tables;' );
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

elif [[ "${dbAuth}" == "0" ]]; then

    for currentTable in $(mysql -NBA -h "${dbHost}" -D "${DB}" --execute='show tables;' );
    do
        #Append current status into a log file for reference.
        printf "DUMPING TABLE #:%u of %u, %-50s on %-20s \n" "$tbl_count" "$tablesInDB" "${currentTable}" "$(date +'%A %m-%d-%Y at %k%M hours')" >> "${outputDir}"_db_export_log.txt

        #Display output to screen for monitoring.
        printf "DUMPING TABLE #:%u of %u, %-50s on %-20s \n" "$tbl_count" "$tablesInDB" "${currentTable}" "$(date +'%A %m-%d-%Y at %k%M hours')";

        #Export the table, and if specified, compress it.
        if [ "${setCompress}" == "1" ]; then
            mysqldump -h "${dbHost}" "${DB}" "${currentTable}" |command gzip > "${outputDir}"/"${currentTable}".sql.gz
        else
            mysqldump -h "${dbHost}" "${DB}" "${currentTable}" > "${outputDir}"/"${currentTable}".sql
        fi

        (( tbl_count++ ))
    done

fi
checkAndReport;