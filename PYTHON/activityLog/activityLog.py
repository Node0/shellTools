import os
import sys
import shutil
import subprocess
import platform
import re
import argparse
from datetime import datetime
import time
import tarfile

### TODO: redesign as a class object (OOP)

class ActivityLogger(object):
	"""Generates a log file for server activity, CPU load, and MySQL statistics."""
	def __init__(self):
		super(ActivityLogger, self).__init__()
		self.checkcronjob()
		self.epochflag = False
		self.rootcheck = False
		self.mysql_usr = None
		self.mysql_pass = None
		self.mysql_queries = 0
		self.mysql_interval = 0
		self.logfilename = None
		### Get server specs
		self.current_platform = platform.platform().lower() # platform information in lower case

		
	def checkcronjob(self):
		print("checkcronjob() has run")
		# Checks to see if script was run by user, or a cron job.
		# Will create actLogDir in home dir if cron, current working directory 
		# if run by user.
		# Explained: sys.stdin will be a TTY if run by console (by the user).
		if os.isatty(sys.stdin.fileno()):
			self.cronjob = False
			self.silent_mode = False
		else:
			self.cronjob = True
			self.silent_mode = True


	def run_command(self, cmd):
		return subprocess.Popen(
			cmd, 
			shell=True, 
			stdout = subprocess.PIPE, # stdout in [0]
			stderr = subprocess.PIPE).communicate() # stderr in [1]

	def dateString(self, epoch = False):
		# should we use GMT instead for consistency?
		localtime = time.localtime()
		# returns time from epoch.  ON UNIX, it is 0 hours on Jan. 1st, 1970
		if epoch == True: 
			return time.time
		elif epoch == False:
			dateTime = "{}_{}_{}__at_{}h_{}m_{}s".format(
				localtime[1], # month
				localtime[2], # mday (day of the month)
				localtime[0], # year
				localtime[3], # hour
				localtime[4], # minute
				localtime[5]) # seconds
			return dateTime

	# Returns a tuple of the stdout and stderr of a command. 
	# NOTE that the use of shell=True is extremely dangerous from a security standpoint. Using it
	# here because the alternative (parsing each command and argument into a list) makes piping
	# multiple commands difficult.
	def run_command(self, cmd):
		return subprocess.Popen(
			cmd, 
			shell=True, 
			stdout = subprocess.PIPE, # stdout in [0]
			stderr = subprocess.PIPE).communicate() # stderr in [1]

	def dateString(self, epoch = False):
		# returns time from epoch.  ON UNIX, it is 0 hours on Jan. 1st, 1970
		if epoch == True: 
			return time.time()
		elif epoch != True:
		# using UTC (Similar to GMC)
			dateTime = datetime.utcnow().strftime("%mm_%dd_%Yy__at_UTC_%Hh_%Mm_%Ss")
			return dateTime


	def rootFsRwRoStateCheck(self):
	# Checks to see if root (/) directory is read/write 
		try:
			with open("/proc/mounts", "r") as f:
				for line in f:
					if " / " in line and "rw" in line:
						return True
				return False
		except:
			if self.silent_mode == "False":
				print("Opening /proc/mounts failed.  Returning False")
				return False
			else:
				return False


	def topRC(self):
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
			if self.silent_mode == False:
				print("Cannot write to ~/.toprc.")

	def getServerLoad_BASH(self):
	# OLD BASH WAY OF GETTING SERVER LOAD 
	# TODO: just read "/proc/loadavg and take first 3 space separated chunks."
		cmd = ("""uptime | grep -Pio "average\:(\s\d{1,}\.\d{1,}\,){1,}(\s\d{1,}\.\d{1,})" |"""
		"""sed -r "s~(average\:\s)~~g" |"""
		"""sed -r "s~\,~~g" |"""
		"""sed -r "s~\s~__~g" """
		)
		return self.run_command(cmd)

	def getServerLoad(self):
		try:
			serverLoad = os.getloadavg()
		except:
			try:
				with open("/proc/loadavg", "r") as f:
					f_split = f.read().split(" ")
					f_joined = "_".join(f_split[:3])
					return f_joined
			except:
				return self.getServerLoad_BASH()[0].decode('utf-8')
				

		serverLoad_formatted = ""
		for i in serverLoad:
			serverLoad_formatted += "{}_".format(i)
		return serverLoad_formatted

	def createLogDir(self, actLogDir = "~/activityLog"):
		# Check/create log directory

		# Checks to see if script was run by user, or a cron job.
		# Will create actLogDir in home dir if cron, current working directory 
		# if run by user.
		if self.cronjob == True:
			# Expands "~" to user home dir
			actLogDir = os.path.expanduser(actLogDir)
			# Clever way to check if directory exists, and create it if it does not
			# without creating a "race" situation.  Google it.
			try:
				os.makedirs(actLogDir)
			except OSError:
				if not os.path.isdir(actLogDir):
					raise
		else:
			actLogDir = "./"

		return actLogDir

	def generateLogFilename(self):
		# Doesn't work in Python3, why?  SOmething to do with how it handles strings.
		# uptime_label = str(uptimeLabel()[0]).rstrip() # gets uptimelabel and eliminates end of line
		serverLoad = self.getServerLoad()
		thisSlice = self.dateString(False) # get date slice without epoch flag set

		# check for epoch filename prefix flag
		if self.epochflag:
			# print("Epoch flag is set")
			thisSliceEpoch = str(self.dateString(epoch = True)) + "-"
		else:
			thisSliceEpoch = "" # will prefix the filename with nothing

		# Generate filenames
		if self.rootcheck: # If root system file check flag is set
			if self.rootFsRwRoStateCheck() and self.fileWriteTest(): # if rootFS(rw) is true and filewritetest is successfull 
				logFileName = "load_avg__{}_fs-is-mounted-RW__at_{}.log".format(
					serverLoad, thisSlice)
			if self.rootFsRwRoStateCheck() and self.fileWriteTest() == False: 
				logFileName = "load_avg__{}_fs-is-mounted-??__at_{}.log".format(
					serverLoad, thisSlice)
			if self.rootFsRwRoStateCheck() == False and self.fileWriteTest(): 
				logFileName = "load_avg__{}_fs-is-mounted-??__at_{}.log".format(
					serverLoad, thisSlice)
			if self.rootFsRwRoStateCheck() == False and self.fileWriteTest() == False: 
				logFileName = "load_avg__{}_fs-is-mounted-RO__at_{}.log".format(
					serverLoad, thisSlice)
		else:
			logFileName = "load_avg__{}_at_{}.log".format(
				serverLoad, thisSlice)
		logFileName = thisSliceEpoch + logFileName # concatenate strings 
		return logFileName

	def fileWriteTest(self):
		try:
			with open("/testfile.tmp", 'w') as f:
				f.write("Test file contents")
				f.close()
				os.remove("/testfile.tmp")
				return True
		except:
			# print("Cannot write to root (/) directory.")
			return False

	def getTopOutput(self):
		# Doesn't work on cygwin, using bottom version in the meantime.
		# cmd = """top -b -M -H -n1""" 
		cmd = "top -b -H -n1" 
		return self.run_command(cmd)[0].decode('utf-8')

	def getNDeviceThroughput(self):
		cmd = "netstat -i"
		return self.run_command(cmd)[0].decode('utf-8')

	def getDaemonsAndPorts(self):
		cmd = "netstat -plunt"
		return self.run_command(cmd)[0].decode('utf-8')

	def getNetworkConnections(self):
		cmd = "netstat"
		return self.run_command(cmd)[0].decode('utf-8')

	def sampleMySQL(self):
		# TODO: setup error handling for this
		cmd = "mysql -u{} -p{} --execute \"show full processlist;\"".format(
			self.mysql_usr, self.mysql_pass)
		return self.run_command(cmd)[0].decode('utf-8')

	def createTar(self, actLogDir = "~/activityLog"):
		logcation = "{}/{}".format(actLogDir, self.logfilename)
		tarlogcation = "{}/{}.tar.gz".format(actLogDir,self.logfilename)
		try:
			with tarfile.open(tarlogcation, "w:gz") as tar:
				tar.add(logcation)
			os.remove(logcation)
		except Exception as e:
			if self.silent_mode == False:
				print("Error creating tar.gz file.  Exception {}.".format(e))

	def writeTheLog(self, actLogDir = "~/activityLog"):
		timestamp = self.dateString()
		actLogDir = self.createLogDir()
		self.createLogDir(actLogDir)
		logcation = "{}/{}".format(actLogDir,self.logfilename)
		try:
			with open(logcation, 'w') as logfile:
				logfile.write(self.getTopOutput())
				logfile.write("\n\n\n\n\n\n\n")
				logfile.write("Thoroughput on NetWork Interfaces:\n")
				logfile.write(self.getNDeviceThroughput())
				logfile.write("\n\n")
				logfile.write("Daemons and Open Ports list:\n")
				logfile.write(self.getDaemonsAndPorts())
				logfile.write("\n\n")
				logfile.write("Network Connections:\n")
				logfile.write("\n\n\n\n\n\n\n")
				# Insert the MySQL bit here
				if self.mysql_usr != None:
					for i in range(self.mysql_queries):
						logfile.write("MySQL Queries Active at {}".format(timestamp))
						logfile.write("\n")
						logfile.write(self.sampleMySQL())
						logfile.write("\n\n")
						time.sleep(self.mysql_interval)
		except Exception as e:
			if self.silent_mode == False:
				print("Error writing to log file. Exception: {}".format(e))

		# Call createTar() and archive this bitch
		self.createTar(actLogDir)


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
	# Initiate the ActivityLogger class object
	activitylog = ActivityLogger()
	# Populate activitylog variables from args
	activitylog.epochflag = args['epoch']
	activitylog.rootcheck = args['rootcheck']
	activitylog.mysql_usr = args['mysql_usr']
	activitylog.mysql_pass = args['mysql_pwd']
	activitylog.mysql_queries = args['mysql_queries']
	activitylog.mysql_interval = args['mysql_interval']

	### Get server specs
	current_platform = platform.platform().lower() # platform information in lower case

	### Activates MySQL process logging if args['mysql_usr'] is set
	# There is a better way to do error handling.  Use try/except somehow.
	if args['mysql_usr'] != None:
		if "Id" not in activitylog.sampleMySQL():
			print("activityLog: MySQL credentials return invalid response.")
			quit()

	### DO ALL THE STUFF
	# activitylog.topRC()
	# Make the damn log file
	if activitylog.silent_mode == False:
		print("Logfile: {}{}.tar.gz".format(
			activitylog.createLogDir(),
			activitylog.generateLogFilename()))
	activitylog.logfilename = activitylog.generateLogFilename()
	if activitylog.silent_mode == False:
		print("Writing activityLog file...")
	activitylog.writeTheLog()


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
		# if run_command("which netstat") == "":
		# 	print("Netstat not installed")
		# 	quit()
		# elif run_command("which mysql") == "":
		# 	print("MySQL not installed")
		# 	quit()
		# else:
		main()
	else:
		# TODO: make this work in Windows and misc environments
		print("This script is designed for use on Linux systems only.")
