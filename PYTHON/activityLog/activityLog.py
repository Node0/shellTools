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

def dateString(epoch = False):
	# should we use GMT instead for consistency?
	localtime = time.localtime() 
	# returns time from epoch.  ON UNIX, it is 0 hours on Jan. 1st, 1970
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


def rootFsRwRoStateCheck():
# Checks to see if root (/) directory is read/write 

	# Mount, filtered to whatever is mounted as /, filtered by whether "rw"
	# is on that line.
	cmd = "mount | grep -Pi \"^(.+on)(\s{1,})(\/\s)\" | grep -Pio \"(rw)\""
	rootrw = run_command(cmd)[0].decode('utf-8')
	if rootrw.rstrip() == "rw":
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
		# print("Cannot write to root (/) directory.")
		return False

def topRC(silent_mode):
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
		if silent_mode == False:
			print("Cannot write to ~/.toprc.")

def getServerLoad_BASH():
# OLD BASH WAY OF GETTING SERVER LOAD 
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
		return getServerLoad_BASH()[0].decode('utf-8')
	serverLoad_formatted = ""
	for i in serverLoad:
		serverLoad_formatted += "{}_".format(i)
	return serverLoad_formatted

def generateLogFilename(args):
	# Doesn't work in Python3, why?  SOmething to do with how it handles strings.
	# uptime_label = str(uptimeLabel()[0]).rstrip() # gets uptimelabel and eliminates end of line
	serverLoad = getServerLoad()
	thisSlice = dateString(False) # get date slice without epoch flag set

	# check for epoch filename prefix flag
	if args['epoch']:
		# print("Epoch flag is set")
		thisSliceEpoch = dateString(args['epoch']) + "-"
	else:
		thisSliceEpoch = "" # will prefix the filename with nothing

	# Generate filenames
	if args['rootcheck']: # If root system file check flag is set
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

def createLogDir(args, actLogDir = "~/activityLog"):
	# Check/create log directory

	# Checks to see if script was run by user, or a cron job.
	# Will create actLogDir in home dir if cron, current working directory 
	# if run by user.
	if args['cronjob'] == True:
		actLogDir = os.getcwd()
	else:
		# Expands "~" to user home dir
		actLogDir = os.path.expanduser(actLogDir)

		# Clever way to check if directory exists, and create it if it does not
		# without creating a "race" situation.  Google it.
		try:
			os.makedirs(actLogDir)
		except OSError:
			if not os.path.isdir(actLogDir):
				raise

	return actLogDir

def getTopOutput():
	# Doesn't work on cygwin, using bottom version in the meantime.
	# cmd = """top -b -M -H -n1""" 
	cmd = "top -b -H -n1" 
	return run_command(cmd)[0].decode('utf-8')

def getNDeviceThroughput():
	cmd = "netstat -i"
	return run_command(cmd)[0].decode('utf-8')

def getDaemonsAndPorts():
	cmd = "netstat -plunt"
	return run_command(cmd)[0].decode('utf-8')

def getNetworkConnections():
	cmd = "netstat"
	return run_command(cmd)[0].decode('utf-8')

def sampleMySQL(user, pwd):
	# TODO: setup error handling for this

	cmd = "mysql -u{} -p{} --execute \"show full processlist;\"".format(
		user, pwd)
	return run_command(cmd)[0].decode('utf-8')

def writeTheLog(args, silent_mode, logfilename, actLogDir = "~/activityLog"):
	timestamp = dateString()
	actLogDir = os.path.expanduser(actLogDir)
	createLogDir(args, actLogDir)
	logcation = "{}/{}".format(actLogDir,logfilename)
	try:
		with open(logcation, 'w') as logfile:
			logfile.write(str(getTopOutput()))
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
			if args['mysql_usr'] != None:
				for i in range(args['mysql_queries']):
					logfile.write("MySQL Queries Active at {}".format(timestamp))
					logfile.write("\n")
					logfile.write(sampleMySQL(args['mysql_usr'], args['mysql_pwd']))
					logfile.write("\n\n")
					time.sleep(args['mysql_interval'])
			logfile.close()
	except Exception as e:
		if silent_mode == False:
			print("Error writing to log file. Exception: {}".format(e))


def main():
	### Create argument parameters. 
	# TODO: Find a way to make it case-insensitive.  Something about type = str.lower, 
	# but I dont know where.
	parser = argparse.ArgumentParser(
		description='Creates a general \'timeslice\' snapshot of activity on a server.')
	parser.add_argument('--epoch', help='Prefix log filename with current epoch.', 
		action="store_true")
	parser.add_argument('--rootcheck', 
		help='Checks if root filesystem is r/w and includes it in the log filename.'
		' Typically requires root access to run.', 
		action="store_true")
	parser.add_argument('--mysql_usr', 
		help='MySQL username for localhost. Activates MySQL state logging.')
	parser.add_argument('--mysql_pwd', 
		help='MySQL password for --mysql_usr.',
		default = "")
	parser.add_argument('--mysql_queries', 
		help='Number of MySQL queries for each report. Default = 60.', default = 60)
	parser.add_argument('--mysql_interval', 
		help='Delay between MySQL queries, in seconds. Default = 0.25.', default = 0.25)
	args=parser.parse_args()
	# Convert args namespace to dictionary
	args = vars(args)

	### Get server specs
	current_platform = platform.platform().lower() # platform information in lower case

	# Checks to see if script was run by user, or a cron job.
	# Will create actLogDir in home dir if cron, current working directory 
	# if run by user.
	# Explained: sys.stdin will be a TTY if run by console (by the user).
	if os.isatty(sys.stdin.fileno()):
		args['cronjob'] = False
	else:
		args['cronjob'] = True
	if args['cronjob'] == True:
		silent_mode = True
	else:
		silent_mode = False


	### Activates MySQL process logging if args['mysql_usr'] is set
	# There is a better way to do error handling.  Use try/except somehow.
	if args['mysql_usr'] != None:
		if "Id" not in sampleMySQL(args['mysql_usr'], args['mysql_pwd']):
			print("activityLog: MySQL credentials return invalid response")
			quit()

	### DO ALL THE STUFF
	topRC(silent_mode)
	# Make the damn log file
	if silent_mode == False:
		print("Logfile: {}{}".format(createLogDir(args), generateLogFilename(args)))
	logfilename = generateLogFilename(args, silent_mode)
	if silent_mode == False:
		print("Writing activityLog file...")
	writeTheLog(args, logfilename)


if __name__ == '__main__':
	# Check environment before running logfile creation.  Perhaps run this in main() ?
	current_platform = platform.platform().lower() # platform information in lower case
	if "linux" in current_platform or "cygwin" in current_platform:
		# Expand this to all used BASH commands, return values in a list of True/False
		# and check if False in the list/array.
		# Use better error handling.  Try/Except with a while True
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
