##############################################################################
# 
# Twingle Library of Functionation
#
# Any function that's used more than once in twingle should go here. 
# Unless it's awesome enough for it's own file.
#
##############################################################################

# Global Variables
$iniGlob = @{}
$twingleDir = "C:\twingle" #hardcoded because. 
$debug = 0
$nesting = ""

function twingleDir {   
	return $twingleDir
}

# Pause function
function pause ($message ="Press any key to continue... ") { 
	write-host -nonewline $message
	$null = $Host.ui.rawui.readkey("noecho,includekeydown")
	write-host ""
}


# Parse the INI configuration file into a nice thing.
Function Parse_IniFile  ($file) {
  if (!$file) { $file = "$twingleDir\twingle.cfg"} 
  $ini = @{}
  switch -regex -file $file {
    "^\[(.+)\]$" {
      $section = $matches[1].Trim()
      $ini[$section] = @{}
    }
    "^\s*([^#].+?)\s*=\s*(.*)" {
      $name,$value = $matches[1..2]
      $ini[$section][$name] = $value.Trim()
    }
  }  
  
  set-variable -name iniGlob -value $ini  -scope 1 
  return $ini
}


function getConfig ($config){ 
	if (!$iniGlob) { log "No globtable"; return "NO VALUE"}
	else {
	$value = $iniGlob["config"][$config]
	if ($value.length -eq 0) { "Config not found: $config"}	
	return $value
	}
}


#Passive Nagios Check submit
function set_nagios_status ($result, $Text) {
       #CUSTOMISE THIS YOURSELF!
       # You can send passive checks to nagios here. This is left as an exercise for the reader.

       #save a copy to the log file
       $logfile = "$twingleDir\twingle.log"
       log "Nagios Passive Check submitted: $result : $Text"

}

# Debug mode - sets the global debug variable to enable logging to stdout
function debug_mode { 
	set-variable -name debug -value 1 -scope 1
}


# Log otuput to file, with nice date stamps
function log ($text) {
	$logfile = "$twingleDir\twingle.log"
	$date = Get-Date -format G
	if ($nesting.length -ne 0) { $buff = "  "} 
	$output = "$date - $buff$nesting $Text"
	$output | Out-File $logfile -Append
	if ($debug -eq 1) { $output }
}

# Any bad bad errors logs to file, nagios and closes program.
function error ($text) { 
   log "ERROR: $text"
   $nagioserror = getConfig nagioserror #config for error severity
   set_nagios_status $nagioserror $text
   log $text
   log "ERRORED out on above message"
   exit 0
} 


# functionality to allow nested output (calls to new files have ">>", amount determined by depth)
function logging ($direction, $file) {
	#set-variable -name exefile -value  $file  -scope 1
	if ($direction -eq "start") {
		$new = $nesting + ">"; set-variable -name nesting -value $new  -scope 1 
		log "start - $file.ps1" }
	if ($direction -eq "end") { 	
		log "end - $file.ps1"
		$c = $nesting.length; $new = $nesting.substring(0,$c-1); set-variable -name nesting -value $new  -scope 1 
		 }
}

# Nice searching of existing scheduled tasks
function get_task ($taskname=""){
    $filename = [System.IO.Path]::GetTempFileName()
    invoke-expression "schtasks /query /fo csv /v " | out-file $filename
    $lines=Get-Content $filename
 if ($lines -is [string]){
    return $null
 } else {
        if ($lines[0] -ne ''){
   Set-Content -path $filename -Value ([string]$lines[0]).Replace(" ","").Replace(":","_")
   $start=1
  } else {
   Set-Content -path $filename -Value ([string]$lines[1]).Replace(" ","").Replace(":","_")
   $start=2
  }
  if ($lines.Count -ge $start){
   Add-content  -Path $filename -Value $lines[$start..(($lines.count)-1)]
  }
  $tasks=Import-Csv $filename
  Remove-Item $filename
  $retval=@()
  foreach ($task in $tasks){
   if (($taskname -eq '') -or $task.TaskName.contains($taskname)){
    $task.PSObject.TypeNames.Insert(0,"DBA_ScheduledTask")
    Add-Member -InputObject $task -membertype scriptmethod -Name Run -Value { schtasks.exe /RUN /TN $this.TaskName /S $this.HostName}
    Add-Member -InputObject $task -membertype scriptmethod -Name Delete -Value { schtasks.exe /DELETE /TN $this.TaskName /S $this.HostName}
    $retval += $task
   }
  }
  return $retval
 }
}


# Banneration!
function banner ($text, $colour) { 
	if ($text -eq "blank") {$text = ""}
	$char = " "
	if ($text -eq "hashbanner") { $char = "#"; $text = ""}
	$width = 60
	$buff = ($width - $text.length )/2
	for ($i = 0; $i -le $buff; $i++) {
		$buffer += $char
	 } 
	$buffer += $text
	for ($i = 0; $i -le $buff; $i++) {
		$buffer += $char
	} 
	if ($colour) { 
		write-host $buffer -foreground $colour 
	} else { write-host $buffer
	}
}

# Create scheduled task - minimal functionality compared to schtasks proper, but added OS logic.
function schedule_task ($name, $type, $day, $time, $action ) { 
	#Yarr
	log "getting schtask config"
	$noschtask = getconfig noschtask
	if ($noschtask -eq 0) { 
		$OSVersion = invoke-expression "wmic os get Caption /value"
		if ($OSVersion -match "2008") { $commands =  " /NP /RL HIGHEST" }
		if ($OSVersion -match "2003") { $commands = "/RU SYSTEM" } 

		#$type - Weekly, Once, OnStart
		#$name - freeform 
		#$day/$time - ignore for OnStart
		
		if ($type -eq "ONSTART") { $timing = "/RU SYSTEM"; }
		if ($type -eq "ONCE") {  $timing = "/sd $day /st $time"; if ($day.length -le 10) { $day = "0"+$day}}	
		if ($type -eq "WEEKLY") {  $timing =  "/d $day /st $time";  }
		
		$schedtask = "schtasks /create /tn `"$name`" $schedtask /TR `"$action`" /sc $type  $timing /f $commands"

		log "Scheduled Task to invoke: $schedtask"
		
			$output = invoke-expression $schedtask	
		if ($output -match "SUCCESS") { 
			log "Task $name successfully created. " 
			if ($type -eq "WEEKLY") { return 0 } 
		} else { 
			error "Scheduled task could not be created." 
			set_nagios_status WARNING "Scheduled task error: could not create $type task"
			if ($type -eq "WEEKLY") { return 1 } 
		}
	} else { "No scheduled task to be created, because config says not to"; return 0}
}

#Remove task named $TaskName
function remove_schtask ($TaskName) { 

	$output = invoke-expression "schtasks /delete /tn `"$TaskName`" /f"
	if ($output -match "SUCCESS") { 
		log "Task $TaskName deleted successfully" 
	} else { 
		log "Task $TaskName deletion failed" 
	}
}

# Nice date formatting functions (for schtasks)
function format_time ($date) { 
    return (get-date $date -format HH:mm)
} 
function format_date ($date) { 
    return (get-date $date -format dd/MM/yyyy)
} 
