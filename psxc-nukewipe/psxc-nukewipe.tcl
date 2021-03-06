## Configuration

set psxcnc(NUKEWIPE) "/glftpd/bin/psxc-nukewipe"
set psxcnc(CMDPRE) "!PS"
set psxcnc(SITENAME) "\[PS\]"

######## The bind option - by default anyone can use this command #########

bind pub -|- [set psxcnc(CMDPRE)]nukewipe psxc_nukewipe

######################## End Configuration ################################
###########################################################################

proc psxc_nukewipe {nick uhost hand chan argv} {
    global psxcnc
    putquick "PRIVMSG $chan :\002$psxcnc(SITENAME)\002 - \037NUKEWIPE:\037 Hold on - cleaning nukes on site..."
    foreach psxcline [split [exec $psxcnc(NUKEWIPE) [lindex $argv 0] [lindex $argv 1]] "\n"] {
      putserv "PRIVMSG $chan :\002$psxcnc(SITENAME)\002 - \037NUKEWIPE:\037 $psxcline"
    }
    putserv "PRIVMSG $chan :\002$psxcnc(SITENAME)\002 - \037NUKEWIPE:\037 Done."
}
putlog "Loaded: psxc-nukewipe v0.03 psxc(C)2006"

