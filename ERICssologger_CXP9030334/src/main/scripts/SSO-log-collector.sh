#!/bin/bash

#####################################
#
# SSO-log-collector.sh
#
# Read Parse and redirect logs to syslog
#
# COPYRIGHT Ericsson 2012
#
#####################################


TAIL=/usr/bin/tail
LOG_FILES=$(ls -d /var/log/sso/Link_*)
AWK=/bin/awk
CAT=/bin/cat
GREP=/bin/grep
KILL=/bin/kill
MKDIR=/bin/mkdir
RM=/bin/rm
TOUCH=/bin/touch

SCRIPT_LOCK_DIR=/tmp/sso_log_collector.lock
SCRIPT_LOCK_PID_FILE=${SCRIPT_LOCK_DIR}/.sso_log_collector_pid
SCRIPT_NAME=`basename $0`
LOGGER_TAG="TOR_SSO_LOG"


getLock() {
	# Local vars local script_pid
	# Check for safe SCRIPT_LOCK_DIR setting
	if ! echo -e "${SCRIPT_LOCK_DIR}" | ${GREP} "^/tmp/" >/dev/null; then
		error "Error: Invalid SCRIPT_LOCK_DIR setting: [${SCRIPT_LOCK_DIR}]. Lock directory must be created under /tmp\n"
		#exit 1
		exit 0
	fi
	if [ ! -d "${SCRIPT_LOCK_DIR}" ]; then
		$MKDIR -p ${SCRIPT_LOCK_DIR} 2> /dev/null
	fi
	# Lock FAILED - check for stale lockinfo " HC lock FAILED; checking for stale lock ..."
	MY_SCRIPT_pid=($$)
	$TOUCH ${SCRIPT_LOCK_PID_FILE}
	SCRIPT_pid=`(${CAT} ${SCRIPT_LOCK_PID_FILE})`
	info " Lock PID file contains: ${SCRIPT_pid}"
	if [ -n "${SCRIPT_pid}" ]; then
		info "Current pid ${SCRIPT_pid} , my pid ${MY_SCRIPT_pid} "
		if [ "${MY_SCRIPT_pid}" ==  "${SCRIPT_pid}" ]; then
			echo -e ${MY_SCRIPT_pid} > ${SCRIPT_LOCK_PID_FILE}
			info "I locked the file"
			LOCKED=0
		else
			# Wait a bit before assuming stale lock i.e. a script
			# was interrupted after acquiring the lock but before
			# it could install the interupt handler to remove it
			sleep 5
		fi


		# Check for active process with discovered pid
		$KILL -0 ${SCRIPT_pid} 2> /dev/null
		if [ "${?}" = "0" ]; then
			# Another active process already has the lock
			error "Error: Another process with PID [${SCRIPT_pid}] has locked this admin function. Please try later.\n"
			LOCKED=1
			return 1
		else
			# Remove stale lock
			[ -d "${SCRIPT_LOCK_DIR}" ] && $CAT /dev/null > ${SCRIPT_LOCK_PID_FILE}
			info " Removed stale HC lock."
			echo -e "${MY_SCRIPT_pid}" > ${SCRIPT_LOCK_PID_FILE}
			LOCKED=0
		fi
	else
		info "My value set in current lock file, locking"
		echo -e "${MY_SCRIPT_pid}" > ${SCRIPT_LOCK_PID_FILE}
		LOCKED=0
	fi
# There is no active process with this pid - remove stale lock [ -d "${SCRIPT_LOCK_DIR}" ] && $RM -rf ${SCRIPT_LOCK_DIR} echo " No active process with PID [$SCRIPT_pid]; Removed stale HC lock."
# Try to lock again getHCLock
}

releaseLock() {
	info "In ReleaseLock"
	# Check for safe SCRIPT_LOCK_DIR setting
	if ! echo -e "${SCRIPT_LOCK_DIR}" | ${GREP} "^/tmp/" >/dev/null; then
		error "Error:  Invalid SCRIPT_LOCK_DIR setting: [${SCRIPT_LOCK_DIR}]. Lock directory must be created under /tmp\n"

		exit 0
	fi
	# Check lock exists
	if [ ! -d "${SCRIPT_LOCK_DIR}" ]; then
		info " No lock to release."
		LOCKED=0
		return 0
	fi
	local SCRIPT_pid=$($CAT ${SCRIPT_LOCK_PID_FILE} 2>/dev/null)
	if [ -z "${SCRIPT_pid}" ]; then
		# Wait a bit
		sleep 5
		local SCRIPT_pid=$(${CAT} ${SCRIPT_LOCK_PID_FILE} 2>/dev/null)
	fi


	# Decide lock is stale if still no pid
	if [ -z "${SCRIPT_pid}" ]; then
		# Remove stale lock
		[ -d "${SCRIPT_LOCK_DIR}" ] && $RM -rf ${SCRIPT_LOCK_DIR}
		info " Removed stale HC lock."
		LOCKED=0
		return 0
	fi
	# Release only if this process has the lock
	if [ "${SCRIPT_pid}" = "$$" ]; then
		# Release the lock
		[ -d "${SCRIPT_LOCK_DIR}" ] && $RM -rf ${SCRIPT_LOCK_DIR}
		info " Released HC lock [${SCRIPT_LOCK_DIR}]."
		LOCKED=0
		exit 0
		return 0
	fi
	# Not locked by this processinfo " This process [$$] tried to release a HC lock but process [$SCRIPT_pid] is the lock owner."
	LOCKED=1
	return 1
}

info()
{
	if [ ${#} -eq 0 ]; then
		while read data; do
			logger -s -t ${LOGGER_TAG} -p user.notice "INFORMATION ( ${SCRIPT_NAME} ): ${data}"
		done
	else
		logger -s -t ${LOGGER_TAG} -p user.notice "INFORMATION ( ${SCRIPT_NAME} ): $@"
	fi
}

log()
{
	if [ ${#} -eq 0 ]; then
		while read data; do
			logger -s -t ${LOGGER_TAG} -p user.notice "${data}"
		done
	else
		logger -s -t ${LOGGER_TAG} -p user.notice "$@"
	fi
}

error()
{
		logger -t ${LOGGER_TAG} -p user.err "ERROR ( ${SCRIPT_NAME} ): $@"
}


start_tailing()
{
	#echo -e "${LOG_FILES}"
	l_counter=1
	while [ $l_counter -le 5 ]
		do
		if [[ -z $LOG_FILES ]]; then
			info "LOG_FILES variable is empty"
			sleep 8
			LOG_FILES=$(ls -d /var/log/sso/Link_*)
			((l_counter++))
		else 
			info "LOG_FILES is Not Empty !"
			l_counter2=1
				while [ $l_counter2 -le 5 ]
				do
					LinkNumber=$(for i in ${LOG_FILES}; do echo $i; done | wc -l)
					if [[ $LinkNumber -eq 7 ]]
					then
						info "Tailing is starting !"
						$TAIL -F ${LOG_FILES} | \
							$AWK -F '\t|^"|"$' \
								'/^$/ || /^==>/ || /^#/ {next};\
								{print $3 "    " $4 "    " $6 "    " $7 "    " $11;\
								fflush()}' | \
							logger -t ${LOGGER_TAG} -p authpriv.notice 2>/dev/null
						break
					else
						if [[ $l_counter2 -eq 5 ]]
						then
							error "Missing some of the Link files. Make sure UpdateSymlink is running"
							releaseLock
						fi
						((l_counter2++))
						sleep 5
					fi
				done
			break
		fi
	done
	info "start tailing is terminating and releasing lock"	
	releaseLock
}

#########MAIN##############################

#get lock
getLock

if [ "$LOCKED" == 0 ];
	then
	info "Exclusive lock obtained on script, continuing...."
else
	info "This Script appears to be locked by another process, exiting "
	info "Exiting with return code 1"
	exit 1
fi

trap "releaseLock" HUP QUIT TERM INT

#start tailing
start_tailing 2>/dev/null

#default exit
exit 0

