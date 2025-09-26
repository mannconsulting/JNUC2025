#!/bin/zsh
###############################################################################################################################################
# WORKFLOW NAME
# Created by:    Mann Consulting (support@mann.com)
# Summary:       Write a nice short summary of what this script does here. Keep it simple and link to external documentation
#                to provide more details. Also remember, displays have more horizontal space than vertical space so go wide!
#
# Documentation: https://mann.com/jnuc2025
#
# Note:          This script is a peek at what we do at Mann Consulting for our Jamf Pro Workflows subscribers
#                It's being released as part of our JNUC 2025 presentation. If you'd like to learn more about our services please visit:
#                https://mann.com/jamf
###############################################################################################################################################
### Global Variables
VERSIONDATE='20250925'        # Format YYYYMMDD - used for version control
APPLICATION="ApplicationName" # Change to your application name for logging
LOCKED_THRESHOLD=604800       # If the computer is locked for this long (7 days) then exit to prevent issues with Jamf policies blocking other policies.
SHUTDOWN_THRESHOLD=2592000    # If the computer is locked for this long (30 days) then prompt for shutdown.
MINSWVERSION=13               # Minimum macOS version required to run this script
DATADOGAPI=""                 # Add your Datadog API key here to enable Datadog logging, otherwise leave blank. NOTE: Mann recommends encryping your API keys.
icon=""                       # Path to icon to use in jamfHelper windows  
#MARK: Start Default Header
##### Start Default Header 20250925
zmodload zsh/datetime
PATH="/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin"
scriptPath=${0}
currentUser=${$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }'):-UnknownUserName}
currentUserID=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/kCGSSessionUserIDKey :/ { print $3 }')
currentUserHome=$(dscl . -read Users/${currentUser} | grep ^NFSHomeDirectory | awk '{print $2}')
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
LogDateFormat="%Y-%m-%d %H:%M:%S"
starttime=$(strftime "$LogDateFormat")

### Start Logging 20250728
readonly jamfVarJSSID=$(defaults read "/Library/Managed Preferences/com.mann.jamfuserdata.plist" JSSID 2>/dev/null || echo 0)
readonly JSSURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url 2>/dev/null) \
         hostname=${hostname:-$(hostname)} \
         computername=${computername:-$(scutil --get ComputerName 2>/dev/null)} \
         serialnumber=${serialnumber:-$(ioreg -d2 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')} \
         SESSIONID=${jamfVarJSSID}-$RANDOM
declare -rA levels=(DEBUG 0 INFO 1 WARN 2 ERROR 3)
LOGGING=INFO DATADOGLOGGING=INFO

printlog() {
  [[ -z "$2" ]] && 2=INFO
  [[ -z "$1" ]] && return
  local log_message log insidelogrepeat=0 previous_line
  if [[ ${1//[$'\n']/} != "$1" ]]; then
    while read log; do
      if [[ $log == $previous_line ]]; then
        let insidelogrepeat=$insidelogrepeat+1
        continue
      fi
      previous_line="$log"
      if [[ $insidelogrepeat -gt 2 ]]; then
        log_message+="Last line repeated ${insidelogrepeat} more times\n"
        local insidelogrepeat=0
        log_message+="$log\n"
      fi
      log_message+="$log\n"
    done <<< "$1"
  else
    log_message=$1
  fi
  log_priority=$2
  local timestamp=$(strftime '%Y-%m-%d %H:%M:%S')
  local logLength=${#log_message}
  if [[ $logLength -ge 76000 ]]; then
    local leftOver=${log_message:76000}
    log_message=${log_message:0:75999}
  fi
  if [[ "$log_message" == "$previous_log_message" ]]; then
    ((logrepeat++)); return
  elif (( logrepeat > 0 )); then
    echo "$timestamp $previous_log_priority: Last message repeated $logrepeat more times"
    [[ -n "$DATADOGAPI" ]] && send_to_datadog "Last message repeated $logrepeat more times" "$previous_log_priority"
    logrepeat=0
  fi
  previous_log_message="$log_message"; previous_log_priority="$log_priority"
  [[ ${levels[$log_priority]:-0} -ge ${levels[$LOGGING]:-1} ]] && { echo "$timestamp $log_priority: $log_message"; logger -t "Mann-$APPLICATION" "Mann-$APPLICATION: $log_message" &|; }
  [[ -n "$DATADOGAPI" && ${levels[$log_priority]:-0} -ge ${levels[$DATADOGLOGGING]:-1} ]] && send_to_datadog "$log_message" "$log_priority"
  if [[ -n $leftOver ]]; then printlog $leftOver $log_priority; fi
}

send_to_datadog() {
  local msg="$1" level="$2"
  ((INDEX++))
  if [[ "${redaction:l}" != "disabled" ]]; then
    msg="${msg//${hostname:-PROTECTED_HOSTNAME}/PROTECTED_HOSTNAME}"
    msg="${msg//${computername:-PROTECTED_COMPUTERNAME}/PROTECTED_COMPUTERNAME}"
    msg="${msg//${serialnumber:-PROTECTED_SERIALNUMBER}/PROTECTED_SERIALNUMBER}"
    msg="${msg//${currentUser:-PROTECTED_USERNAME}/PROTECTED_USERNAME}"
    msg="${msg//${password:-PROTECTED_PASSWORD}/PROTECTED_PASSWORD}"
  fi
  msg="${msg//\"/\\\"}"
  msg="${msg//$'\n'/\\n}"
  curl -H "Content-Type: application/json" -H "DD-API-KEY: $DATADOGAPI" -m 15 -s \
       -X POST https://http-intake.logs.datadoghq.com/v1/input \
       -d "{\"message\":\"$msg\",\"level\":\"$level\",\"http.url\":\"$JSSURL\",\"application\":\"$APPLICATION\",\"version\":\"$VERSIONDATE\",\"index\":\"$INDEX\",\"env\":\"$SWVERSIONLONG\",\"sessionid\":\"$SESSIONID\"}" >/dev/null &|
}

jamfPrettyExit() {
  message=${1}
  message="${message//\//\\/}" # Escape forward slashes
  policyLogFile=$(ps -p $PPID | tail -1 | awk -F"'" '{print $(NF-1)}')
  if [[ -f "$policyLogFile" ]]; then
    sed -i '' '1s/^/\'$'\n/g' "$policyLogFile"
    sed -i '' '1s/^/####################################################\'$'\n/g' "$policyLogFile"
    sed -i '' '1s/^/'"${message//$'\n'/\\n}"'\'$'\n/g' "$policyLogFile"
    sed -i '' '1s/^/####################################################\'$'\n/g' "$policyLogFile"
    sed -i '' '1s/^/\'$'\n/g' "$policyLogFile"
  fi
}

cleanupAndExit() { # $1 = exit code, $2 message
  printlog "$2" $3
  jamfPrettyExit "$2"
  printlog "################## End $APPLICATION (took $((( (`strftime %s` - `date -jf $LogDateFormat $starttime +%s`) ))) seconds)" INFO
  exit "$1"
}
### End Logging

### Start beenLockedSince 20250925
beenLockedSince() {
  local -r waitSeconds=$1
  local count=0
  lastLoginRaw=$(last -s | grep -v root)
  if [[ ${lastLoginRaw} != *"still logged in"* ]]; then
    lastLogin=$(echo $lastLoginRaw | grep -v "still logged in" | grep console | head -1)
    lastLoginTime=$(echo ${lastLogin} | awk '{ print $3, $4, $5, $6}')
    lastLoginEpoch=$(date -j -f "%a %b %d %H:%M" "${lastLoginTime}" +%s)
    lastLoginLength=$(echo ${lastLogin} | cut -d '(' -f 2 | cut -d ')' -f1 | xargs)
    lastLogoutEpoch=$((${lastLoginEpoch} + ${lastLoginLength} ))
    currentEpoch=$(strftime %s)
    lockTime=$((${currentEpoch} -  ${lastLogoutEpoch} ))
  else
    local xpath='//key[text()="IOConsoleUsers"]/following-sibling::array[1]/dict[1]/key[text()="CGSSessionScreenLockedTime"]/following-sibling::integer[1]/text()'
    local lockTime=$(ioreg -n Root -d1 -a | xmllint --xpath $xpath - 2>/dev/null)
  fi
  upTime=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//')
  if [[ -z $lastLoginRaw && -z $lockTime && $currentUserID == 88 ]]; then
    currentEpoch=$(strftime %s)
    lockTime=$((${currentEpoch} -  ${upTime} ))
  fi

  if [[ -n "${lockTime}" ]]; then
    if [[ -n $upTime && $(( $(strftime %s) - ${lockTime} )) -gt $(( $(strftime %s) - ${upTime} )) ]]; then
      lockTime=$upTime
    fi

    printf "%d" $(( $(strftime %s) - $lockTime ))
  else
    printf "%d" 0
  fi
}

getHUDIdleTime() {
  hudIdleNanoseconds=$(ioreg -c IOHIDSystem | grep -i "HIDIdleTime" | awk '{print $NF}')
  echo $((hudIdleNanoseconds / 1000000000))
}

lockedSeconds=$(beenLockedSince)
if [[ $lockedSeconds -gt 0 && -n $LOCKED_THRESHOLD && $lockedSeconds -ge $LOCKED_THRESHOLD ]]; then
  printlog "################## Start $APPLICATION $VERSIONDATE - computer locked for ${lockedSeconds} seconds." INFO
  cleanupAndExit 1 "Computer has been locked for over ${LOCKED_THRESHOLD} seconds, exiting to prevent issues with Jamf policies blocking other policies." WARN
elif [[ $lockedSeconds -gt 0 ]]; then
  printlog "################## Start $APPLICATION $VERSIONDATE - computer locked for ${lockedSeconds} seconds." INFO
else
  printlog "################## Start $APPLICATION $VERSIONDATE - computer unlocked. Last input was $(getHUDIdleTime) seconds ago." INFO
fi
printlog "System uptime is $(uptime)" INFO
if ! curl -s --max-time 10 https://www.google.com > /dev/null 2>&1; then
    printlog "Google connectivity check failed - unable to reach google.com. Some downloads or functions may have issues." WARN && googleFailed=true && googleFailedLog=WARN
else
    printlog "Google connectivity check passed" INFO && googleFailed=false && googleFailedLog=ERROR
fi
### End beenLockedSince
### Start waitForUnlock 20240410
waitForUnlock() {
  local -r waitSeconds=$1
  local count=0
  while (( $count < $waitSeconds )); do
    if [[ $(beenLockedSince) -gt 0 ]]; then
      sleep 10
      count=$(( $count + 10 ))
    else
      return 0
    fi
  done
  return 1
}
### End waitforUnlock
### Start runAsUser 20240419
runAsUser() {
  if [[ $currentUser != "loginwindow" ]]; then
    uid=$(id -u "$currentUser")
    launchctl asuser $uid sudo -u $currentUser "$@"
  fi
}
### End runAsUser
### Start macOS Version Check 20250417
SWVERSIONLONG=$(sw_vers -productVersion)
SWVERSIONSHORT=$(echo $SWVERSIONLONG | cut -d "." -f 1-2)
SWVERSIONMAJOR=$(echo $SWVERSIONLONG | cut -d "." -f 1)
if [[ -z $MINSWVERSION ]]; then MINSWVERSION=13; fi
if [[ $(bc -l <<< "$SWVERSIONSHORT < $MINSWVERSION") -eq 1 ]];then
  cleanupAndExit 1 "Computer doesn't meet minimum macOS requirements, current version is ${SWVERSIONLONG} but the minimum required version is ${MINSWVERSION}. Upgrade the computer to the latest versin of macOS to continue." WARN
else
  printlog "$(sysctl hw.model | awk '{ print $2 }') running macOS version $SWVERSIONLONG" INFO
fi
### End macOS Version Check
### Start shut down on idle 20250304
if [[ $lockedSeconds -gt 0 && -n $SHUTDOWN_THRESHOLD && $lockedSeconds -ge $SHUTDOWN_THRESHOLD ]]; then
  button=$(runAsUser "$jamfHelper" -windowType utility -title  "Computer Activity Required" -description "To ensure compliance, $COMPANY requires your computer be activly used so that updates and security patches are properly applied.

Since your computer has been inactive for over 30 days it will automatically shut down when the timer below expires." -icon "$icon" -countdown -timeout 1200 -defaultButton 1 -button1 "Shut Down" -button2 "Cancel")
  if [[ $button == 2 ]]; then
    printlog "User canceled inactivity shutdown. This shouldn't happen.  Debugging: $(last -s) " ERROR
  else
    shutdown -h +300s
    cleanupAndExit 1 "User hasn't been present for $lockedSeconds seconds, triggering inactivity shutdown." WARN
  fi
fi
### End shutdown on idle
#MARK: End Default Header

# Start your scripty stuff here
printlog "Hello! This is a test script with a debug statement." DEBUG

# Use runAsUser to run commands as the current user, like Jamf helper.  Stuff shouldn't run as root unless it needs to.
runAsUser "$jamfHelper" -windowType utility -title  "Good Day Check" -description "Hi, I hope you're having a good day!" -icon "$icon" -timeout 1200 -defaultButton 1 -button1 "I am" -button2 "Go away"

# Do more scripty stuff here, possibly come across an error.
printlog "This is only a test of an error. Maybe include install.log? $(tail -n 100 /var/log/install.log)" ERROR

# Do even more scripty stuff here, printa. quick log.
printlog "Goodbye! This was only a test." INFO

if [[ -d "/Applications/Google Chrome.app" ]]; then
  cleanupAndExit 0 "Google Chrome is installed, script completed successfully." INFO
else
  cleanupAndExit 1 "Google Chrome isn't installed, script failed." ERROR
fi
