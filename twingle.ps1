# Twingle Reloaded

$TwingleFolder = $MyInvocation.MyCommand.Definition.replace("twingle.ps1","")
$Twingle       = $TwingleFolder+"twingle"
$Config_File   = $TwingleFolder+"config.ini"
$Config_Log    = $TwingleFolder+"twingle.log"

$Param_SchTaskTime   = "08:00" 	   # Time of day to send emails, etc
$Param_RebootDelay   = 5  	   # reboot delay for "immediate" reboots

$SchtaskNames = @{}
$SchTaskNames.Add("-patchTuesday"  , "Twingle Patch Tuesday")
$SchTaskNames.Add("-notifyClient"  , "Twingle - Maintenance Notification")
$SchTaskNames.Add("-installUpdates", "Twingle Updates for ")
$SchTaskNames.Add("-reboot"        , "Reboot $(gc env:computername)")
$SchTaskNames.Add("-postReboot"    , "Twingle Post Reboot")

function log ($text) { 	
	$output = ""+(get-date -format u).replace("Z","")+" $text"
	$output | out-file $Config_Log -append
	write-debug $output
} 

function error ($text,$nagios="yes") { 
	$output = ""+(get-date -format u).replace("Z","")+" ERROR: $text"
	$output | out-file $Config_Log -append
	write-error $text
	if ($nagios -eq "yes") { nagios "CRITICAL" "$text" }
	"Twingle is exiting" | out-file $Config_Log -append
	exit
} 

function warning ($text) { 	
	$output = "WARNING: "+(get-date -format u).replace("Z","")+" WARNING: $text"
	$output | out-file $Config_Log -append
	write-warning $output
} 

function schedtask ($parameter, $flags) { 
	$name = ($schtasknames.get_item($parameter)) 
	if ($parameter -eq '-installUpdates') { $name += "$("{0:MMMM}" -f $InstallDate) $($installDate.Year)" }
	
	$OScmd = ""	
	if ($parameter -match "-postReboot")   { $OScmd += "/RU SYSTEM " }
	elseif ( (invoke-expression "wmic os get Caption /value") -match "2003") { $OScmd += "/RU SYSTEM " }
	else  { $OScmd += "/NP /RL HIGHEST "}
	
	$cmd = "schtasks /create /tn `"$name`" /TR `"powershell $twingle $parameter`" $flags /F $OScmd"
	$temp = [System.IO.Path]::GetTempFileName()
	cmd.exe /c "`"$cmd 2>&1`""  | out-file $temp; $result = get-content $temp
	$result | % { if ($_ -match "SUCCESS") {
			log ($_.replace("SUCCESS","Scheduled task CREATED successfully"))
		} elseif ($_ -match "ERROR")  {
			error "Could not create scheduled task using code '$cmd'. Result: $_"; 
		} elseif ($_ -match "INFO") { 
			#ignore, 2003 likes to tell us if things were created as specific users.
		} else { 
			warning "SchedTask had a bad result: $result" 
		}
	}
} 

function get_task ($taskname=""){
    $filename = [System.IO.Path]::GetTempFileName()
    invoke-expression "schtasks /query /fo csv /v " | out-file $filename
    $lines=Get-Content $filename
	if ($lines -is [string]){ return $null} else { if ($lines[0] -ne ''){
		Set-Content -path $filename -Value ([string]$lines[0]).Replace(" ","").Replace(":","_"); $start=1
	} else { Set-Content -path $filename -Value ([string]$lines[1]).Replace(" ","").Replace(":","_"); $start=2  }
	if ($lines.Count -ge $start){ Add-content  -Path $filename -Value $lines[$start..(($lines.count)-1)] }
	$tasks=Import-Csv $filename;  Remove-Item $filename;  $retval=@()
	foreach ($task in $tasks){
	if (($taskname -eq '') -or $task.TaskName.contains($taskname)){
		$task.PSObject.TypeNames.Insert(0,"DBA_ScheduledTask")
		Add-Member -InputObject $task -membertype scriptmethod -Name Run -Value { schtasks.exe /RUN /TN $this.TaskName /S $this.HostName}
		Add-Member -InputObject $task -membertype scriptmethod -Name Delete -Value { schtasks.exe /DELETE /TN $this.TaskName /S $this.HostName}
		$retval += $task
	} } return $retval }
}

function removeschedtask ($parameter) { 
	$result = get_task ($schtasknames.get_item($parameter)) 
	if ($result) { 
		$name = $result.TaskName.replace("\","") 
	} else {$DoNotRemove = 1}
	if (!$DoNotRemove) { 
		$result = invoke-expression "schtasks /delete /tn `"$name`" /f"
		log "$result"
	} else { log "No scheduled tasks exist for paramter, so nothing shall be removed." }
} 	

function nagios ($result, $text) { 	
	# IMPLEMENT ME!
	# Use your nice notification systems to give the result $result and
	# text $text to your minions. 
	# Result will be OK, WARNING, or CRITICAL
} 

log "~~~~~~~~~~~~~~ Twingle Invoked: $args ~~~~~~~~~~~~~~"

if ($args.length -eq 0) { "Twingle -- argument required. See [[twingle]]"; exit }

if ($args -match "-installScript"){ 
	
	log "Installing the twingle script"
	$mWP=new-object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
	$adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator	
	if (!$mWP.IsInRole($adm))   {"Installing Twingle must be done as an Administrator";	exit}
	
	$Config_Variable = "InstallDay","InstallTime","RebootTime"
	$Config_Text = "What is the installation day (MON/TUE/WED/THU)"`
				  ,"What is the installation time (HH:MM)"`
				  ,"After installation, when should we reboot (NOW, or HH:MM)"
	$Config_Default = "WED","18:00","NOW"
		
	for ($i = 0; $i -lt $Config_Variable.length; $i++) { 
		$input = read-host "$($Config_Text[$i]) ? `[$($Config_Default[$i])`]"
		if ($input.length -ne 0) { $Config_Default[$i] = $input }
	} 
		
	log "Defaults selected: $Config_Default. Saving to file: $Config_File"
	"[Twingle]" | out-File $Config_File
	for ($i = 0; $i -lt $Config_Variable.length; $i++) { 
		"$($Config_Variable[$i])=$($Config_Default[$i])" | out-file $Config_File -append
	}
 
 	# CHANGE ME
 	# Ensure the system hs the PSWindowsUpdate module 
	
	schedtask "-patchTuesday" "/sc monthly /mo SECOND /d TUE /st $Param_SchTaskTime"
	
	"`n`nTwingle has been installed on the system"
	"Configuration as follows`nInstallation Day: $($Config_Default[0])"
	"Installation Time: $($Config_Default[1])`nAfter updates, when to reboot: $($Config_Default[2])`n"
	
	nagios "OK" "Twingle installed on system."
	
	log "Twingle has finished -installScript"; exit
} 

if (Test-Path $Config_File) {
	get-content $Config_File | %{ 
		if ($_ -match "InstallDay")  { $Config_Day  = $_.substring($_.indexof("=")+1)}
		if ($_ -match "InstallTime") { $Config_Time = $_.substring($_.indexof("=")+1)}		
		if ($_ -match "RebootTime") { $Config_Reboot = $_.substring($_.indexof("=")+1)}
	}
	log "Twingle loaded with configuration: $Config_Day, $Config_Time, $Config_Reboot"
} else { error "No config file found at location $Config_file. Twingle cannot continue."; exit}


if ($args -match "-patchTuesday") {

	log "Twingle will now perform patch Tuesday things."
	
	try { 

		$Today = get-date
		switch($Config_Day) { "WED" {$Day="Wednesday"} "MON" {$Day="Monday"}"TUE"{$Day="Tuesday"}"THU"{$Day="Thursday"}}
		$InstallNum = [int]([System.DayOfWeek]$Day)
		$InstallDate = $Today.AddDays($InstallNum+5)
		
		$notifyStep = -5; if ($installNum = 3) { $notifyStep = -3 } 
		$notifyDate = $InstallDate.AddDays($notifyStep)
		log "Installation Date: $installDate  :: Notify Date: $notifyDate"
		
		log "Schedule installaion of updates on the installation date"
		$parmeters = "/sc ONCE /sd $(get-date $InstallDate -format dd/MM/yyyy) /st $Config_Time"
		schedtask "-installUpdates" $parmeters
		
		log "scheduling the notification on the notification date, a few business days before installation."
		$parameters = "/sc ONCE /sd $(get-date $notifyDate -format dd/MM/yyyy) /st $Param_SchTaskTime"
		schedtask "-notifyClient" $parameters
		
		log "Twingle has finished -patchTuesday";	exit
	} catch { error $_.Exception.Message }
}

if ($args -match "-notifyClient") { 
	
	log "Maintenance notification is being sent"
	
	# CHANGE ME
	# Send an email, or other notification to your clients. 
	
	removeSchedtask "-notifyClient"
	log "Twingle has finished -notifyClient";	exit	
} 

if ($args -match "-installUpdates" ) {

	if ($Config_Reboot -eq 'NONE') { 
		nagios "WARNING" "Manual update time! Do your worst, citizens!"
		log "Sysadmins notified about manual updates"
		
		log "Scheduling post-reboot hook for execution after manual reboot."
		schedtask "-postReboot" "/sc ONSTART"
	} 
	else { 
		nagios "WARNING" "Updates are installing..."
		log "Twingle will now install all pending updates on the system.. please wait.."
		
		try {			
			Import-module PSWindowsUpdate #Wowzers. http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
			$List = Get-WUInstall -AcceptAll -ListOnly

			if ($List.count -eq 0 -or !$List) { 
				log "There are no pending updates." 
			} else { 
				$list | %{ $KBs += ", "+$_.KB }
				log "Updates pending: $($KBs.substring(2))"
				log ("Total of "+$List.count +" updates are pending, installing now using Get-WUInstall")
				
				Get-WUInstall -AcceptAll -IgnoreReboot
				log "Updates have been installed"
			}

			if( Get-WURebootStatus -Silent) {
				log "A reboot is required to complete updates"  
				if ($Config_Reboot -eq "NOW") { 
					$RebootDateTime = (get-date).AddMinutes($Param_RebootDelay)
					log "Configuration states the machine will reboot in a few moments, at $RebootDateTime"
				} else { 
					$RebootDateTime = (get-date -hour ([int]$Config_Reboot.Substring(0,2)) -minute ([int]$Config_Reboot.Substring(3,2)) -second 0)
					if ($RebootDateTime -lt (get-date)) { $RebootDateTime = $RebootDateTime.AddDays(1)} 			
					log "Configuration states the machine will reboot a delayed time, at $RebootDateTime"
				}				
				log "Sending a netsend message to anyone who's currently logged in, regarding pending restarts."
				$msgcode = "msg * Warning: $(gc env:computername) will be rebooting at $schedreboottime on $RebootDateTime for scheduled updates."
				invoke-expression $msgcode
				
				$parmeters = "/sc ONCE /sd $(get-date $RebootDateTime -format dd/MM/yyyy) /st $(get-date $RebootDateTime -format HH:mm)"
				schedtask "-reboot" $parmeters
				
				nagios "WARNING" "This machine will reboot at $RebootDateTime to complete updates"			
			} else { 
				log "No reboot is required by the system." 
				nagios "OK" "No reboot is required."
			}		
			
		} catch { error "An error occurred during update installation: $error" } 
		removeSchedtask "-installUpdates"
		log "Twingle has finished -installUpdates";	exit
	}
}
	
if ($args -match "-reboot") { 
	log "Twingle will now start the pre-reboot tasks"
	
	log "Forking process for: Pre-reboot hook"
	powershell .\pre_reboot_hook.ps1

	log "Scheduling post-reboot hook"
	schedtask "-postReboot" "/sc ONSTART"

	invoke-expression "msg * $(gc env:computername) will restart in 10 seconds."
	log "Twingle will restart the system in 10 seconds. Have a nice day"
	$cmd = "shutdown /r /t 10 /c `"Twingle initiated reboot for Windows Update completion`""
	invoke-expression $cmd
	
	removeSchedtask "-reboot"
	log "Twingle has finished -reboot";	exit
}

if ($args -match "-postreboot") { 
	log "Twingle will now start the post-reboot tasks, since the system has now rebooted."
	
	log "Forking process for: post-reboot hook"
	powershell .\post_reboot_hook.ps1
	
	nagios "OK" "Machine has successfully rebooted after updates."
	
	removeSchedtask "-postreboot"
	log "Twingle has finished -postreboot";	exit
} 
