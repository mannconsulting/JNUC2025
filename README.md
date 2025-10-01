# Welcome
Welcome to Mann Consulting's GitHub repo sharing some code we presented at our Jamf Nation User Conference (JNUC) 2025 session. As a Jamf MSP we manage a large number of Jamf instances and heavily rely on centralized scripting and logging to achieve our goals at scale. This session primarily focuses on how to level up your Jamf Pro scripting using some discipline and techniques we’ve developed to ensure that your computers are always checking in and completing their directed tasks. 

# Default Header.sh
The default header is the base for versioning and managing common functions utilized across all scripts. Here you can perform version control on functions and ensure that you’re never re-writing code base and always using something you’ve perfected. 

At the top we start with some details about the script and global variables that can be used to control these functions.  
* VERSIONDATE: What version of the script we’re running, this will be logged in datadog for easy troubleshooting.
* APPLICATION: Differentiate your applications in Datadog logging
* LOCKED_THRESHOLD: If the system is locked for more than this amount of seconds when the script starts running, just exit. (see beeLockedSince function below)
* SHUTDOWN_THRESHOLD: If the system has been locked for this amount of seconds when the script starts running, shut it down. (see Shutdown on Idle below)
* MINSWVERSION: If the system is running a software version lower than this, just exit. 
* DATADOGAPI: Datadog write only API key to send logs to Datadog.  NOTE: Storing API keys in scripts can be a risk, Mann actively encrypts theirs and recommends you do as well. Encryption functions are not included and should be completed per your organization's security guidance. 
* icon= Path to a local png file to use as an icon in branded jamfHelper dialogs.

Next we’ll also define some commonly used variables that are used as shortcuts in most scripts:
* PATH: Lock the path to only use built in apple tools, this avoids homebrew tools from inadvertently breaking your scripts due to differing options or unwanted execution of commands at root (ruh oh)
* currentUser: currently logged in user
* currentUserID: UID of the current user
* currentUserHome: Home directory of the currently logged in user
* jamfHelper: JamfHelper has SUCH a long path… instead just use $jamfHelper!

## printlog
The core of our workflows ride on our ability to centrally log success, failure and data points for each script run.  The printlog function not only adds features like timestamps to your Jamf policy log output but also sends logging to Datadog for advanced processing. Once in Datadog you can create dashboards providing metrics or alerts for critical issues that require attention.

## jamfPrettyExit
Jamf policy logs can be hard to read for even an experienced scripting wizard, let alone Jr. techs.  Jamf pretty exit helps this by allowing you insert your final output for policy script final output at the TOP of the logs instead of the bottom. This can easily indicate the outcome of each script run.

<img width="1026" height="472" alt="Screenshot 2025-10-01 at 12 42 18 PM" src="https://github.com/user-attachments/assets/7705a13b-552b-4ab5-8026-afc76412ab7f" />

## cleanupAndExit
Just exiting your script can be messy, instead define some basic functions on exit. A default cleanupAndExit function in the default header will properly exit and run jamfPrettyExit, log how long the script took to complete and more. If you’d like more functions on exiting add another cleanupAndExit function after your default header to override the defaults!  Use it to cleanup temporary files, verify the state of affairs and more!

## beenLockedSince
Sometimes you need input from the employee using the computer to proceed, for example if you’re quitting chrome to update it.  But what if the employee isn’t present and has been missing in action for days? To avoid sitting and waiting for a button that will never get clicked you can utilize this to define what you’ll do if the computer has been locked for a long time.  Some options here:


* Define the LOCKED_THRESHOLD variable to determine if you’re just going to exit and try again later.
* Report lock status when starting each script, including the last time the mouse or keyboard was used (HUDIdleTime) to diagnose issues that may be related to employee inactivity.

## waitForUnlock
Maybe you care about employee presence but don’t want to just exit if the employee isn’t there.  Pass a number in seconds to waitForUnlock to have your script wait to see if the computer unlocks while we’re waiting, when it does immediately proceed with execution to get input. One strategy is to cleanupAndExit if the wait for unlock time isn’t met.

```
if ! waitForUnlock 600; then
  cleanupAndExit 1 "Waited 600 seconds for screen unlock and screen is still locked. The screen has been locked for $(beenLockedSince) seconds." WARN
fi
```
## runAsUser
Don’t run EVERYTHING as root, only what’s necessary.  Use this when you need to execute a command as root or if you’re opening an application that they will interact with to avoid potential privilege escalations. This works great with executing jamfHelper, Swift Dialog and other apps that interact with the employee.

## macOS Version check
Set a minimum version required for your script to avoid issues with older versions of macOS incorrectly handling commands or not providing all  the necessary binaries by default.

## Shutdown on Idle
Lastly - If a client computer is online for more than 30 days but doesn’t have anyone using it then it could be a security risk. Updates may not be applied to macOS or applications, your compliance benchmarks or patch reporting may always have a smudge on it due to inactive systems. 
