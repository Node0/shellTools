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
# Name: tableTaker.sh
# Version: v0.2
# Release: Stable
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


function showUsage {

    clear;
    echo "Usage: $(basename "$0") [--host=foo] [--user=bar] [--database=bat] [--outputdir=baz] [--compress]";
    echo "----------------------------------------------------------------";
    echo "Parameters with an asterisk are optional:";
    echo "      Hostname: --host=localhost or --host=<IP ADDRESS> i.e. --host=xxx.xxx.xxx.xxx";
    echo " Database User: --user=<MYSQL USERNAME> or Omit this param if no authentication is needed for CLI access to MySQL.";
    echo "      Database: --database=<DATABASE NAME>";
    echo "   *Output Dir: --outputdir=<DIRECTORY NAME> Directory will be created relative to the location of this script.";
    echo "  *Compression: --compress Omit this param to forego compression of exported table SQL.";
    echo "----------------------------------------------------------------";
    echo -ne "\n";

    #This whole database-list-preview adventure needs some serious clean-up and refactoring to be more robust.
    previewUserList=( "admin" "mysql" "root" );
    simplePrvwOutput=$(mysql --execute="show databases;" 2>&1);
    if [[ $(echo ${simplePrvwOutput} | grep -P "(information_schema)" ) != "" ]]; then
        echo     "Note: Your MySQL configuration allows direct access to the database server.";
        echo -ne "      Here is a list of all databases available without explicit authentication.\n\n";
        mysql --execute="show databases;"
    else
        #If access to MySQL without a user fails, try some common usernames without specifying a password.
        for userName in "${previewUserList[@]}";
        do
            probedPrvwOutput=$(mysql --user=${userName} --execute="show databases;" 2>&1 );
            if [[ $(echo ${probedPrvwOutput} | grep -P "(information_schema)" ) != "" ]]; then
                echo     "Note: Your MySQL configuration allows the user: ${userName} to access the";
                echo     "      database server without a password. Here is a list of all databases";
                echo -ne "      available to the user: ${userName} without a password.\n\n";
                mysql --user=${userName} --execute="show databases;";
                setNoPreview=0;
            else
                setNoPreview=1;
            fi
        done;
        if [[ "${setNoPreview}" == 1 ]]; then
            echo     "Note: It appears as though your MySQL server is not configured to allow open CLI";
            echo     "      access. This means access to MySQL is not readily available, that is to say";
            echo     "      access without a username, or access with one of the common usernames such as";
            echo -ne "      [mysql, root, admin] without the specification of a password, is not available.\n\n";

            echo     "      Next Steps:";
            echo     "      ----------------------------------------------------------------";
            echo     "      To proceed further you'll need working MySQL login credentials.";
            echo     "      This means either a valid username with a blank password or a valid";
            echo     "      username and password pair with privileges to access the database(s)";
            echo     "      you wish to export.";
        fi
        echo -ne "\n\n";
    fi
    exit 1
}

function processParams {


    # Parameter Regexes
    # Note: Regexes structured with regard for parameter-case
    # in order to ensure smooth interchangability between grep and sed
    # without regard to version (of sed) or system. Per-tool case
    # sensitivity flags 'may' have otherwise resulted in more brittle code.

    hostParam="\-\-[hH][oO][sS][tT]\=";
    userParam="\-\-[uU][sS][eE][rR]\=";
    dbParam="\-\-[dD][aA][tT][aA][bB][aA][sS][eE]\=";
    outputDirParam="\-\-[oO][uU][tT][pP][uU][tT][dD][iI][rR]\=";
    compressionParam="\-\-[cC][oO][mM][pP][rR][eE][sS][sS]";
    ipAddrRgx="\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b";

    # Out of order parameter processing loop (script may be invoked with params given in any order)
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

        # Todo: Look into making this more elegant (integrate with db user param handling logic above)
        if [[ "${dbUser}" == "" ]]; then
            dbAuth="0";
        fi

        #Handle db parameter
        if [[ "$(echo "${param}" |command grep -Po '('${dbParam}')' )" != "" ]]; then
            if [[ "$(echo "${param}" |command sed -r "s~(${dbParam})~~g" )" != "" ]]; then
                setDbString=$(echo "${param}" |command sed -r "s~(${dbParam})~~g");
                DB="${setDbString}";
            fi
        fi

        #Handle output directory parameter
        if [[ "$(echo "${param}" |command grep -Po '('${outputDirParam}')')" != "" ]]; then
            if [[ "$(echo "${param}" |command sed -r "s~(${outputDirParam})~~g" )" != "" ]]; then
                outputDirString=$(echo "${param}" |command sed -r "s~(${outputDirParam})~~g");
                outputDir="${outputDirString}";
            fi
        fi

        #Handle compression parameter
        if [[ "$(echo "${param}" |command grep -Po '('${compressionParam}')')" != "" ]]; then
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
        true;
    else
        showUsage;
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

# Output directory functions
function makeDfltOutputDir {
    thisRunTimeStamp=$(dateString);
    outputDir="${DB}_Exported_on_${thisRunTimeStamp}";
    mkdir "${outputDir}";
}

function makeCustomOutputDir {
    mkdir "${outputDir}";
}

# Run this after everything else is done, if a trainwreck occurred then clean up (wipe out)
# the output directory for said trainwreck.
# Todo: Ask user (with a default fallback behavior) whether to wipe out the failed export directory
# or leave it in place.
function checkAndReport {
    chkOutputDir=$(command ls ${outputDir} |command grep -Pic ".");
    if [[ ${chkOutputDir} == 0 ]]; then
        echo -ne "\n\n\n";
        echo "ATTENTION!! Something went wrong with the export, ${chkOutputDir} tables were exported.";
        echo "Please check your hostname, database name, access credentials, and try again.";
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

# Output directory sanity checking.
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

# If a user param was specified then ask for the password
if [[ "${dbAuth}" == "1" ]]; then
    echo "Please enter the password for the mysql user: ${dbUser}";
    echo "${dbUser}'s password: "
    read -s DB_pass;
fi


echo "Dumping tables into separate SQL files for database '${DB}' in output directory: ${outputDir}"

echo "Log of Table Taker activity as initiated on $(date +'%A %m-%d-%Y at %k%M hours')" |command tee "${outputDir}"_db_export_log.txt
printf "\n\n\n" >> "${outputDir}"_db_export_log.txt

# Get number of tables in Database for running log
if [[ "${dbAuth}" == "1" ]]; then
    tablesInDB=$(mysql -NBA -h "${dbHost}" -u "${dbUser}" -p"${DB_pass}" -D "${DB}" --execute='show tables;' |command grep -c .);
elif [[ "${dbAuth}" == "0" ]]; then
    tablesInDB=$(mysql -NBA -h "${dbHost}" -D "${DB}" --execute='show tables;' |command grep -c .);
fi


tbl_count=0;

# Run different loops (only 1 should ever run at a time) based on whether
# MySQL is accessed with auth credentials or not.

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