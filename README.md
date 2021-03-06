# Shell Tools script collection

#### An assortment of generally useful shell i.e. (BASH, SH, CSH & other language) scripts for use on the command line.

### The scripts comprising shellTools are created with an emphasis on:  
#### - code quality (reliable operation in diverse environments)  
#### - readability (both in source code and tool usage documentation)
#### - comfort in usage (gentle learning curves with sensible default behaviors)  

##_shellTools includes:_
* __activityLog__  
Designed to be run unattended from a cron job, activityLog is a basic  
"system vitals" logging script which creates system activity 'snapshot' tar.gz files.  
**The system load averages (1, 5, 15) & a timestamp are what comprise a snapshot filename.**  
Each such snapshot is a text file containing the following information.  
**1.)** Top  
**2.)** Netstat (Complete connection list, Processeslist per port, & Network throughput/interface)  
**3.)** MySQL processlist (sampled for 15 seconds at 1/4 second resolution)  

(Special thanks to @thefunkjunky for a very clean port of activityLog to python)
  
  
* __diskSpeedTest__  
A simple disk transfer (write) speed test using dd and some  
nested loops to run through a set of many common block sizes  
and counts. __diskSpeedTest__ requires no parameters (not yet anyway)  
and will generate a simple log file describing the performance  
metrics achieved by your storage device at various block sizes & counts.  
  
  
* __tableTaker__
A robust table-by-table data export script for MySQL.  
featuring __timestamped database output directories__ (by default)  
with support for __user specified output directory names.__  
tableTaker also allows __an easy way to compress the exported table output SQL.__
