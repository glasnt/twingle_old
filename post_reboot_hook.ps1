##############################################################################
# 
# Twingle -  Post reboot hook
#
##############################################################################
##############################################################################
# YOUR CODE HERE

$Log_file = (Split-path $MyInvocation.MyCommand.Path)+"\twingle.log"
$date = (get-date -format u).replace("Z","")
"$date Post Reboot Hook initiated" | out-file $Log_file -Append

##############################################################################

exit