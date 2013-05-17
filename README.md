# Twingle for Windows

Twingle is a windows implementation of [Tingle][]. It tries to replicate the original concept of having an automated update system that tries to invoke at least some logic to things. 

# Overview

You have Windows Updates, right? They can be automatically run on a weekly basis, or they can be run to only download things, pending user confirmation of installation. With Twingle, you (should, ideally) be able to schedule updates for as often as you want, and get some feedback out of your server as the process occurs. 

# Features

Some things twingle can do for you:
 - automated installation: just say what day/time of the week you want installs, and twingle does the rest!
  - but you can still customize the installation
 - notify a robot or humanoid about pending installations
 - installs all, or only important updates
 - notifies any logged in users about pending installations
 - cleans up after itself, just like a toilet-trained puppy!

# Installation 
 - Copy the set of twingle files to `C:\twingle`, or similar
 - Run `Install Twingle.bat` to get the mini-installer
  - or run `twingle.ps1 -setup -full` to get the whole shebang
  - automatic installer can be got via `twingle.ps1 -setup -auto -day=DAY -time=XXXX`
 - Set your install day and time (default, weekly), and notification time (3 days before installation)
 - Twingle will do the rest!

# How it works

On setup, Twingle will setup a weekly scheduled task, at your indicated date/time for `notify day`, to check for pending updates. If there are pending updates, it will queue them for installation, and send an email to somewhere to let you know things are pending. It will then schedule the one-off installation task.

On the `install day`, Twingle will set off the installation of whatever updates were marked as being installable. Pending your settings, it will then schedule a reboot of the server, and let anyone on the server know that the server is going to go bye-bye's shortly. 

In all these items, there are nagios hooks to let some automated system know that something's happening (for you to customize). 
# Notes and such

This code is currently very much beta. It is a work in progress, and it's written in Powershell. Both these items should indicate that caution should be used when viewing this code.

Two areas of the code that require customisation from the installer are the `email` and `nagios` hooks. Just search for `CUSTOMISE THIS YOURSELF!` to have a squizz at what needs to be changed. 

# The Config.ini File

There are a few options for this file: 
 * InstallDay: [MON|TUE|WED|THU]  - if you update on a Friday, you're in for a bad time. 
 * InstallTime: (just a 24h time)
 * RebootTime: either a time, or one of the following options: 
   * NOW: "immediately" after installs have finished (a net send msg will be sent to logged in users giving a few minutes warning)
   * NONE: the system will not be restarted. A notification will be send to a human to explain this. 

[Tingle]: http://github.com/anchor/tingle
