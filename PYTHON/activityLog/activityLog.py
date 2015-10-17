import os
import sys
import shutil
import subprocess
import platform
import re
import argparse
import time
import pwd # Not necessary, just a fancy way of getting current real user

# Returns a tuple of the stdout and stderr of a command. 
# NOTE that the use of shell=True is extremely dangerous from a security standpoint. Using it
# here because the alternative (parsing each command and argument into a list) makes piping
# multiple commands difficult.
def run_command(cmd):
	return subprocess.Popen(
		cmd, 
		shell=True, 
		stdout = subprocess.PIPE, # stdout in [0]
		stderr = subprocess.PIPE).communicate() # stderr in [1]

# Returns the date, formatted to specifications set by epoch argument
# OLD BASH VERSION
# def dateString(epoch):
# 	if epoch == True:
# 		cmd = ["command date +'%s' "]
# 	elif epoch == False:
# 		cmd = """command date +'%a %m-%d-%Y at %k%Mh %Ss' |command sed -r "s~(\s)~_~g" |command sed -r "s~(__)~_~g" """
# 	# Need to implement Joe's hcode segment here.
# 	return run_command(cmd)

def dateString(epoch = False):
	# should we use GMT instead for consistency?
	localtime = time.localtime() 
	# returns seconds from epoch
	if epoch == True: 
		return time.time
	elif epoch != True:
		dateTime = "{}_{}_{}__at_{}h_{}m_{}s".format(
			localtime[1], # month
			localtime[2], # mday (day of the month)
			localtime[0], # year
			localtime[3], # hour
			localtime[4], # minute
			localtime[5]) # seconds
		return dateTime


# Checks to see if root directory is read/write 
def rootFsRwRoStateCheck():
	cmd = """mount | grep -Pi "^(.+on)(\s{1,})(\/\s)" | grep -Pio "(rw)"""
	if run_command(cmd)[0] == "rw":
		return True
	else:
		return False

def fileWriteTest():
	try:
		with open("/testfile.tmp", 'w') as f:
			f.write("Test file contents")
			f.close()
			os.remove("/testfile.tmp")
			return True
	except:
		print("Cannot write to root (/) directory.")
		return False

def topRC():
	# Custom ~./toprc config.  I have no idea what is happening here.

	# Expands "~" to user home dir
	toprc_loc = os.path.expanduser("~/.toprc")
	toprcexists = os.path.isfile(toprc_loc)
	toprc = """RCfile for \"top with windows\"
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
        summclr=3, msgsclr=3, headclr=2, taskclr=3"""

	if toprcexists:
		shutil.move(toprc_loc, os.path.expanduser("~/.backup_toprc"))

	try:
		with open(toprc_loc, 'w') as f:
			f.write(toprc)
			f.close()
	except:
		print("Cannot write to ~/.toprc.")

# OLD BASH WAY OF GETTING SERVER LOAD 
def getServerLoad_BASH():
	cmd = ("""uptime | grep -Pio "average\:(\s\d{1,}\.\d{1,}\,){1,}(\s\d{1,}\.\d{1,})" |"""
	"""sed -r "s~(average\:\s)~~g" |"""
	"""sed -r "s~\,~~g" |"""
	"""sed -r "s~\s~__~g" """
	)
	return run_command(cmd)

def getServerLoad():
	try:
		serverLoad = os.getloadavg()
	except:
		return "os.getloadavg_failed"
	# Fix this
	serverLoad_formatted = ""
	for i in serverLoad:
		serverLoad_formatted += "{}_".format(i)
	return serverLoad_formatted

def generateLogFilename(args):
	# Doesn't work in Python3, why?  SOmething to do with how it handles strings.
	# uptime_label = str(uptimeLabel()[0]).rstrip() # gets uptimelabel and eliminates end of line
	serverLoad = getServerLoad()
	thisSlice = str(dateString(False)).rstrip() # get date slice without epoch flag set
	# check for epoch filename prefix flag
	if args.epoch:
		print("Epoch flag is set")
		thisSliceEpoch = str(dateString(args.epoch)[0]).rstrip() + "-"
	else:
		thisSliceEpoch = "" # will prefix the filename with nothing

	# Generate filenames
	if args.showrootfsstate: # If root system file check flag is set
		if rootFsRwRoStateCheck() and fileWriteTest(): # if rootFS(rw) is true and filewritetest is successfull 
			logFileName = "load_avg_{}_fs-is-mounted-RW__at_{}.log".format(
				serverLoad, thisSlice)
		if rootFsRwRoStateCheck() and fileWriteTest() == False: 
			logFileName = "load_avg_{}_fs-is-mounted-??__at_{}.log".format(
				serverLoad, thisSlice)
		if rootFsRwRoStateCheck() == False and fileWriteTest(): 
			logFileName = "load_avg_{}_fs-is-mounted-??__at_{}.log".format(
				serverLoad, thisSlice)
		if rootFsRwRoStateCheck() == False and fileWriteTest() == False: 
			logFileName = "load_avg_{}_fs-is-mounted-RO__at_{}.log".format(
				serverLoad, thisSlice)
	else:
		logFileName = "load_avg_{}__at_{}.log".format(
			serverLoad, thisSlice)
	logFileName = thisSliceEpoch + logFileName # concatenate strings 

	return logFileName

def createLogDir(actLogDir = "~/activityLog"):
	# Log Directory
	# Todo: Re-think this to handle both automatic (cron-triggered) mode
	# as well as an interactively called (by the user) mode. When run interactively
	# by the user, activityLog should place the log file in the same directory
	# the script itself.

	# actLogDir="activityLog"
	# centOsVer=$(cat /etc/redhat-release | sed -r 's~(^.+release)(.+)([0-9]\.[0-9]{1,})(.+$)~\3~g');
	# actLogDir_exists = os.path.isdir(actLogDir)
	# second argument should be permissions octal, default 0777
	# if actLogDir_exists == False: 
	# 	os.mkdir("~/{}".format(actLogDir))

	# Expands "~" to user home dir
	actLogDir = os.path.expanduser(actLogDir)

	try:
		os.makedirs(actLogDir)
	except OSError:
		if not os.path.isdir(actLogDir):
			raise

	return actLogDir

def getTopOutput():
	# Doesn't work on cygwin, using bottom version in the meantime.
	# cmd = """top -b -M -H -n1""" 
	cmd = """top -b -H -n1""" 
	return run_command(cmd)[0]

def getNDeviceThroughput():
	cmd = """netstat -i"""
	return run_command(cmd)[0]

def getDaemonsAndPorts():
	cmd = """netstat -plunt"""
	return run_command(cmd)[0]

def getNetworkConnections():
	cmd = """netstat"""
	return run_command(cmd)[0]

def sampleMySQL(user, pwd):
	# TODO: setup error handling for this

	cmd = "mysql -u{} -p{} --execute \"show full processlist;\"".format(
		user, pwd)
	return run_command(cmd)[0]

def writeTheLog(args, logfilename, actLogDir = "~/activityLog"):
	timestamp = dateString()
	actLogDir = os.path.expanduser(actLogDir)
	createLogDir(actLogDir)
	logcation = "{}/{}".format(actLogDir,logfilename)
	try:
		with open(logcation, 'w') as logfile:
			logfile.write(getTopOutput())
			logfile.write("\n\n\n\n\n\n\n")
			logfile.write("Thoroughput on NetWork Interfaces:\n")
			logfile.write(getNDeviceThroughput())
			logfile.write("\n\n")
			logfile.write("Daemons and Open Ports list:\n")
			logfile.write(getDaemonsAndPorts())
			logfile.write("\n\n")
			logfile.write("Network Connections:\n")
			logfile.write("\n\n\n\n\n\n\n")
			# Insert the MySQL bit here
			if args.mysql_usr != None:
				for i in range(args.mysql_queries):
					logfile.write("MySQL Queries Active at {}".format(timestamp))
					logfile.write("\n")
					logfile.write(sampleMySQL(args.mysql_usr, args.mysql_pwd))
					logfile.write("\n\n")
					time.sleep(args.mysql_interval)
			logfile.close()
	except Exception as e:
		print("Error writing to log file. Exception: {}".format(e))






def main():
	# Create argument parameters. 
	# TODO: Find a way to make it case-insensitive.  Something about type = str.lower, but I dont know where.
	# TODO: make sure ip address is correctly formatted.  Make it optional?
	# TODO: find out why Joe included ip address at all in the first place
	parser = argparse.ArgumentParser(description='Creates a general \'timeslice\' snapshot of activity on a server.')
	parser.add_argument('--ip', help = 'IP address.')
	parser.add_argument('--epoch', help='Epoch filename prefix option.', action="store_true")
	parser.add_argument('--showrootfsstate', help='Checks if root FS is r/w.', action="store_true")
	# parser.add_argument('--sample-mysql', help='Gathers MySQL data.', action="store_true")
	parser.add_argument('--mysql_usr', help='MySQL user')
	parser.add_argument('--mysql_pwd', help='MySQL password')
	parser.add_argument('--mysql_queries', 
		help='Number of MySQL queries for each report. Default = 60.', default = 60)
	parser.add_argument('--mysql_interval', 
		help='Delay between MySQL queries, in seconds. Default = 0.25.', default = 0.25)
	args=parser.parse_args()

	# Check MySQL credentials if --sample_mysql flag set
	# There is a better way to do error handling.  Use try/except somehow.
	if args.mysql_usr != None:
		if "Id" not in sampleMySQL(args.mysql_usr, args.mysql_pwd):
			print "MySQL credentials return invalid response"
			exit()

	# Get server specs
	current_user = pwd.getpwuid(os.getuid())[0] # on UNIX, gets the current real user ID
	# current_user = os.environ['USERNAME'] # alternative multiplatform method for finding current user
	homeDirEnvBackup = os.environ['HOME']
	current_platform = platform.platform().lower() # platform information in lower case
	print(current_platform)

	# Test area
	print(args)
	print("Date: {}".format(dateString(args.epoch)))
	thisSlice = dateString(args.epoch)[0]
	print("Read/Write: {}".format(rootFsRwRoStateCheck()))
	print("fileWriteTest: {}".format(fileWriteTest()))
	topRC()
	if "linux" in current_platform:
		print("Server Load: {}".format(getServerLoad()))
	# cygwin python packages don't include os.getloadavg
	elif "cygwin" in current_platform:
		print("Server Load: {}".format(getServerLoad_BASH()))
	print("Logfile: {}{}".format(createLogDir(), generateLogFilename(args)))

	# Make the damn log file
	logfilename = generateLogFilename(args)
	# print("Top output: {}".format(getTopOutput()))
	# print("Throughput on Network Interface: {}".format(getNDeviceThroughput()))
	# print("Daemons and Open Ports list: {}".format(getDaemonsAndPorts()))
	# print("Network connections: ".format(getNetworkConnections())) # Sits there forever on cygwin
	print("Writing log file...")
	writeTheLog(args, logfilename)


if __name__ == '__main__':
	# Check environment before running logfile creation.  Perhaps run this in main() ?
	current_platform = platform.platform().lower() # platform information in lower case
	if "linux" in current_platform or "cygwin" in current_platform:
		# Expand this to all used BASH commands, return values in a list of True/False
		# and check if False in the list/array.
		# Use better error handling.  Try/Except with a while something == True
		# UPDATE: the above probably not necessary, since mysql and netstat 
		# are the only optional packages used in this script.  
		# STILL: should probably do the alias assignments in the original script,
		# to avoid weird custom aliases fucking shit up.
		if run_command("which netstat") == "":
			print("Netstat not installed")
			quit()
		elif run_command("which mysql") == "":
			print("MySQL not installed")
			quit()
		else:
			main()
	else:
		# TODO: make this work in Windows and misc environments
		print("This script is designed for use on Linux systems only.")
