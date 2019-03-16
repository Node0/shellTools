#!/bin/bash

# Notice
# ----------------------------------------------------------------
# Copyright (C) 2019  Joe J Hacobian
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
# Name: elasticStatMail.sh
# Version: v0.1
# Release: Development
# Author: Joe Hacobian
# Description: Grabs the cluster health from a curl call on localhost
# uses jq to format the ouput, leverages functionality from activityLog.sh
# to grab detailed top output.


# Cron-proofing common commands
netstat=$(which netstat);
uptime=$(which uptime);
whoami=$(which whoami);
md5sum=$(which md5sum);
mkdir=$(which mkdir);
touch=$(which touch);
sleep=$(which sleep);
find=$(which find);
grep=$(which grep);
curl=$(which curl);
date=$(which date);
gzip=$(which gzip);
cut=$(which cut);
awk=$(which awk);
sed=$(which sed);
cat=$(which cat);
top=$(which top);
tar=$(which tar);
rm=$(which rm);
mv=$(which mv);
df=$(which df);
jq=$(which jq);



# Fetch Elasticsearch Cluster Health
esClusterHealthObj=$("${curl}" -s -X GET "localhost:9200/_cluster/health" | "${jq}" '.');

# Some Variables
esClusterUnprocessedShards=$(echo "${esClusterHealthObj}" | "${jq}" -r '. | .["unassigned_shards"] ' );
esClusterNodeCount=$(echo "${esClusterHealthObj}" | "${jq}" -r '. | .["number_of_nodes"] ' );
esClusterName=$(echo "${esClusterHealthObj}" | "${jq}" -r '. | .["cluster_name"] ' );
esClusterStatus=$(echo "${esClusterHealthObj}" | "${jq}" -r '. | .["status"] ' );
dfOutPut=$(df -h);



function configureTop {
topRcContents="RCfile for \"enhanced top metrics\"
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
        summclr=3, msgsclr=3, headclr=2, taskclr=3";

    if [[ $1 == "--setup" ]];
    then
        if [[ -f ~/.toprc ]];
        then
            prevConfigExists=1;
            "${mv}" ~/.toprc ~/.backup_toprc;
            echo "${topRcContents}" > ~/.toprc;
        else
            prevConfigExists=0;
            echo "${topRcContents}" > ~/.toprc;
        fi
    fi

    # Restore the .toprc file which we backed up previously
    if [[ $1 == "--restore" ]];
    then
        if [[ -f ~/.backup_toprc && ${prevConfigExists} == 1 ]];
        then
            "${mv}" ~/.backup_toprc ~/.toprc
        else
                        if [[ -f ~/.toprc && ${prevConfigExists} == 0 ]]
                        then
                        "${rm}" -f ~/.toprc;
                        fi
                fi
    fi
}
configureTop --setup
topOutput=$("${top}" -b -H -n1)
configureTop --restore





esWarningAlertMessage=$(echo -ne "\
Elasticsearch Cluster alert WARNING: \"${esClusterStatus}\" state
==================================================
=============== Cluster Statistics ===============
--------------------------------------------------
Cluster Name:   ${esClusterName}
Cluster Nodes:  ${esClusterNodeCount}
Cluster Status: ${esClusterStatus}
Pending Shards: ${esClusterUnprocessedShards}
--------------------------------------------------");

esEmergencyAlertMessage=$(echo -ne "\
Elasticsearch Cluster alert EMERGENCY: \"${esClusterStatus}\" state
==================================================
=============== Cluster Statistics ===============
--------------------------------------------------
Cluster Name:   ${esClusterName}
Cluster Nodes:  ${esClusterNodeCount}
Cluster Status: ${esClusterStatus}
Pending Shards: ${esClusterUnprocessedShards}
--------------------------------------------------");

esDiskSpaceMessage=$(echo -ne "\
===================================================
=============== Storage Consumption ===============
---------------------------------------------------
$(echo "${dfOutPut}";)
---------------------------------------------------");

esServerProcessesMessages=$(echo -ne "\
===================================================
=============== Compute Utilization ===============
---------------------------------------------------
${topOutput}
---------------------------------------------------");


if [[ "${esClusterStatus}" == "yellow" ]]
then
echo -ne "${esWarningAlertMessage}\n\n\n${esDiskSpaceMessage}\n\n\n${esServerProcessesMessages}\n";
fi

if [[ "${esClusterStatus}" == "red" ]]
then
echo -ne "${esEmergencyAlertMessage}\n\n\n${esDiskSpaceMessage}\n\n\n${esServerProcessesMessages}\n";
fi
