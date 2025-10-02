# Welcome
Welcome to Mann Consulting's GitHub repo sharing some code we presented at our Jamf Nation User Conference (JNUC) 2025 session. As a Jamf MSP, we manage a large number of Jamf instances and rely heavily on centralized scripting and logging to achieve our goals at scale. This session primarily focuses on how to level up your Jamf Pro scripting using the discipline and techniques we’ve developed to ensure that your computers are always checking in and completing their directed tasks. 

# Default Header.sh
The default header is the base for versioning and managing common functions utilized across all scripts. This facilitates both function-level version control and allows easy re-use of core, common functionality.
At the top we start with some details about the script and global variables that can be used to control how these functions behave.  
* `VERSIONDATE`: What version of the script we’re running, in a YYYYMMDD format. This will be logged in Datadog for easy troubleshooting.
* `APPLICATION`: Differentiates your script in Datadog logging, allowing easy filtering when implementing changes or fixing issues within your scripts.
* `LOCKED_THRESHOLD`: If the system is locked for more than this number of seconds when the script starts running, just exit. (see beenLockedSince function below)
* `SHUTDOWN_THRESHOLD`: If the system has been locked for this number of seconds or more when the script starts running, shutdown the Mac. (see Shutdown on Idle below)
* `MINSWVERSION`: If the system is running a macOS version lower than this, the script exits automatically. 
* `DATADOGAPI`: Datadog write-only API key used for sending logs to Datadog.  NOTE: Storing API keys in scripts can be a risk, Mann actively encrypts theirs and recommends you do as well. Encryption functions are not included and should be completed per your organization's security guidance. 
* `icon`: Path to a local png file to use as an icon in branded jamfHelper dialogs.

Next we’ll also define some commonly used variables that are used as shortcuts in most scripts:
* `PATH`: Restrict the PATH to only use built-in Apple tools, this prevents homebrew tools from inadvertently breaking your scripts due to differing options or unwanted execution of commands as root (ruh oh)
* `currentUser`: The username of the currently logged in user
* `currentUserID`: The UID of the currently logged in user
* `currentUserHome`: The Home directory of the currently logged in user
* `jamfHelper`: JamfHelper has SUCH a long path… instead just use $jamfHelper!

## printlog
The core of our workflows rely on our ability to centrally log success, failure and data points for each script invocation.  The printlog function not only adds features like timestamps to your Jamf policy log output, but also sends logging to Datadog for advanced processing. Once in Datadog, you can create dashboards providing aggregate metrics or alerts to surface critical issues that require attention.

## jamfPrettyExit
Jamf policy logs can be hard to read for even an experienced scripting wizard, let alone juniorJr. technicians.  jamfPrettyExit simplifies this by allowing you to redirect the final output for policy script to the TOP of the policy log instead of the bottom. This allows users of all skill levels to quickly identify the outcome of each policy log.

<img width="1026" height="472" alt="Screenshot 2025-10-01 at 12 42 18 PM" src="https://github.com/user-attachments/assets/7705a13b-552b-4ab5-8026-afc76412ab7f" />

## cleanupAndExit
Exiting your script by using exit is a missed opportunity to provide more information or perform cleanup tasks.,. A default cleanupAndExit function in the default header will properly exit and run `jamfPrettyExit`, log how long the script took to complete, and more. If you’d like to run more functions on exit, add another cleanupAndExit function after your default header to override the defaults!  Use it to cleanup temporary files, verify the state of affairs and more!

## beenLockedSince
Sometimes you need input from the employee using the computer to proceed, for example when you’re quitting Chrome to update it.  But what if the employee isn’t present and has been missing in action for days? To avoid sitting and waiting for a button that will never get clicked you can utilize this to define what you’ll do if the computer has been locked for a long time.  Some possibilities include:


* Define the `LOCKED_THRESHOLD` variable to determine if you’re going to exit and try again later.
* Report lock status when starting each script, including the last time the mouse or keyboard was used (HUDIdleTime) to surface issues that may be related to employee inactivity.

## waitForUnlock
Maybe you care about employee presence, but would prefer not to  exit if the employee isn’t there.  Pass a number in seconds to waitForUnlock to have your script wait to see if the computer unlocks while we’re waiting, proceeding normally if they return.. One strategy is to call `cleanupAndExit` if the wait for unlock time isn’t met.

```
if ! waitForUnlock 600; then
    cleanupAndExit 1 "Waited 600 seconds for screen unlock and screen is still locked. The screen has been locked for $(beenLockedSince) seconds." WARN
fi
```

## runAsUser
Don’t run EVERYTHING as root, only what’s necessary.  Use this when you need to execute a user-impersonating command as root or if you’re opening an application that they will interact with to avoid potential privilege escalations. This works great with executing jamfHelper, Swift Dialog and other apps like defaults that interact with the employee or data in their home directory.

## macOS Version check
Set a minimum version required for your script to avoid issues with older versions of macOS incorrectly handling commands or not providing all of the necessary binaries by default. This is handled by the value specific in the `MINSWVERSION` variable, e.g. `MINSWVERSION=15` sets macOS Sequoia as the minimum version necessary for the script to proceed.

## Shutdown on Idle
. A company-managed Mac that remains online but is not in active use may be a security risk in your environment. For example, updates may not be applied to macOS or installed applications, your or compliance benchmarks or patch reporting may include irrelevant or unnecessary data by including inactive systems. This functionality causes these Macs to automatically shutdown after a certain number of days, stopping them from checking in and ultimately tidying your reporting data.
