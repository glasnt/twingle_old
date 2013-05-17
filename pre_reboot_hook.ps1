##############################################################################
# 
# Twingle -  Pre reboot hook
#
##############################################################################

##############################################################################
# YOUR CODE HERE

# e.g. stopping MSSQL before reboot
# $null = invoke-expression "net stop mssqlserver"
# 
# ^^ throw whatever you want after invoke-expression, and it will run as if in Command Prompt

# e.g. stop mssql where there is also a SQL Server Agent
# $stopMSSQLAgent = "net stop `"SQL Server Agent (MSSQLSERVER)`" "
# $stopMSSQL = "net stop mssqlserver"
# $null = invoke-expression $stopmssqlagent
# $null = invoke-expression $stopmssql

##############################################################################

$Log_file = (Split-path $MyInvocation.MyCommand.Path)+"\twingle.log"
$date = (get-date -format u).replace("Z","")
"$date Post Reboot Hook initiated" | out-file $Log_file -Append

exit 