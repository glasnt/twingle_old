##############################################################################
# 
# Twingle (proper)
#
##############################################################################
# 
# Things twingle can do for you! (command line args)
#  -setup   : setup scheduled tasks, check SMTP, create config file
#  -check   : the weekly check for updates, downloading them, scheduling the installation, etc 
# 
#  -warm    : downloads the updates that "-update" logic'd
#  -install : install any and all downloaded updates
#  -reboot  : reboot the server, if required, to apply/finish updates.
#
##############################################################################

$env:PSModulePath = $env:PSModulePath + ";c:\twingle\lib"; 
Import-Module twingle; $ini = Parse_IniFile; $twingleDir = twingledir

# Skip straight to setup if required
if ($args -match "-setup") { 
	invoke-expression "$twingledir\lib\setup_twingle.ps1 $args"
	exit 0
} 

function usage { 
	"Twingle - tingle for windows."
	"Parameters: -setup, -check, -warm, -install, -reboot"
	"See Anchor Wiki documentation [[twingle]] for more information"
	exit 0
}

if (!(Test-Path "$twingledir\twingle.cfg")) { 
	" "
	Write-host "Whoops! " -foreground red -nonewline
	"Twingle doesn't appear to be installed."
	" " 
	""+(Get-Date)+" Twingle config not found, cannot run" | out-file "$twingledir\confignotfound.log" -append
	usage
} 


# debug bonanza
if ($args -match "-debug") { 
	debug_mode
}

# Hardcore logging here. 
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
$null = Start-Transcript -path $twingledir\superlog.log -append

log "*******************************************************"
log "Starting a new twingle run; args: $args"

# Arg Parse.
if ($args) {
  	if ($args -match "-warm") {
		$warm = 1;
	} elseif ($args -match "-install") {
		$install = 1;
	} elseif ($args -match "-reboot") {
		$reboot = 1; 
	} elseif ($args -match "-update") {
		$update = 1; 		
	} elseif ($args -match "-check") {
		$check = 1; 
	} else { 
		log ("Input can't be understood. You said "+$args[0]+"")
	}	
} else { 
	usage
}


if ($warm) { 
	log "Input parameters say: download pending updates"
	invoke-expression "$twingledir\lib\twingle_warm_cache.ps1"
}

if ($install) {
	set_nagios_status OK "Twingle is installing updates..."
	log "Input parameters say: download pending updates, then install"
	
	invoke-expression "$twingledir\lib\twingle_warm_cache.ps1"
	invoke-expression "$twingledir\lib\twingle_install.ps1"
}

if ($reboot) {
	set_nagios_status OK "Twingle is installing updates..."
	log "Input parameters say:  download updates, install them, then reboot"
	invoke-expression "$twingledir\lib\twingle_warm_cache.ps1"
	invoke-expression "$twingledir\lib\twingle_install.ps1"
	invoke-expression "$twingledir\lib\twingle_reboot.ps1"
}

if ($check) { 
	set_nagios_status OK "Twingle is checking for updates..."
	log "Input parameters say: do the weekly check for updates" 
	invoke-expression "$twingledir\lib\twingle_check.ps1"
}

log "Finished the twingle run."

# stop hardcore logging
$null = Stop-transcript | out-null

exit 0
