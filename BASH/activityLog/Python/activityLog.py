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

def dateString(epoch):
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

def topRC():
	toprcexists = os.path.isfile("~/.toprc")
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
		shutil.move("~/.toprc", "~/.backup_toprc")

	try:
		with open("~/.toprc", 'w') as f:
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
	serverLoad_formatted = ""
	for i in serverLoad:
		serverLoad_formatted += "{}.2f".format(i)
	return serverLoad_formatted

def generateFilename(args):
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

def createLogDir(actLogDir = "activityLog"):
	# Log Directory
	# Todo: Re-think this to handle both automatic (cron-triggered) mode
	# as well as an interactively called (by the user) mode. When run interactively
	# by the user, activityLog should place the log file in the same directory
	# the script itself.
	# actLogDir="activityLog"
	# centOsVer=$(cat /etc/redhat-release | sed -r 's~(^.+release)(.+)([0-9]\.[0-9]{1,})(.+$)~\3~g');
	actLogDir_exists = os.path.isfile("~/{}".format(actLogDir))
	# second argument should be permissions octal, default 0777
	if actLogDir_exists != True: os.mkdir("~/{}".format(actLogDir))

def getTopOutput():
	# cmd = """top -b -M -H -n1""" # Doesn't work on cygwin, using bottom version in the meantime.
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




def main():
	# Create argument parameters. 
	# TODO: Find a way to make it case-insensitive.  Something about type = str.lower, but I dont know where.
	# TODO: make sure ip address is correctly formatted.  Make it optional?
	parser = argparse.ArgumentParser(description='Creates a general \'timeslice\' snapshot of activity on a server.')
	parser.add_argument('ipaddress', help = 'IP address.')
	parser.add_argument('--epoch', help='Epoch filename prefix option.', action="store_true")
	parser.add_argument('--sample-mysql', help='Gathers MySQL data.', action="store_true")
	parser.add_argument('--showrootfsstate', help='Checks if root FS is r/w.', action="store_true")
	args=parser.parse_args()

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
	elif "cygwin" in current_platform:
		print("Server Load: {}".format(getServerLoad_BASH()))
	print("Filename: {}".format(generateFilename(args)))
	print("Top output: {}".format(getTopOutput()))
	print("Throughput on Network Interface: {}".format(getNDeviceThroughput()))
	print("Daemons and Open Ports list: {}".format(getDaemonsAndPorts()))
	# print("Network connections: ".format(getNetworkConnections())) # Sits there forever on cygwin


if __name__ == '__main__':
	# This stuff should probably be moved to main()

	# print(current_user)
	if "linux" in current_platform or "cygwin" in current_platform:
		main()
	else:
		print("This script is designed for use on Linux systems only.")
