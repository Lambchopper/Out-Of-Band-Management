#!/bin/bash

#----------------------------------------------------------
#
# Out of Band Management Device Start-up script
#
# Created by: Dave Lamb
# on: 8/19/2014
#
# This script is designed to start and configure all the
# necessary components required by the Out of Band Management
# device.
#
# Required packages: pppd, open-ssh, minicom.
#
# Required Hardware: Raspberry Pi, Cellular Modem, USB-Serial
#  adapter, Powered USB Hub.
#
# /usr/bin/printf commands in script will only display when the script
#  is run manually.  They areu/bin/sed to debug your configuration.
#----------------------------------------------------------

#Start by declaring Configuration variables
#The initial value of these variables are configured in the
#/home/pi/oobm.conf file.
#Hardware Parameters
declare SERIALSTR               #The Search string for the Serial-USB Adapter
declare MODEMSTR                #The Search string for the Modem
declare MINICOMFILE             #The location of the Minicom Configuration File
#PPP Connection Parameters
declare PPPDSCRIPT              #The name of the PPPD connection Script
declare PPPDPATH                #The path to the PPPD connection scripts
declare PPPBUPATH               #The location to backup the PPPd config
declare TESTIP                  #The IP of an internet Host to test
#SSH Reverse Tunnel Parameters
declare PRIVKEY                 #The local Private Key File
declare REMOTEUID               #The User ID on the Remote (To Pi) server
declare SSHIP                   #The Remote (To Pi) serverst start the reverse Tunnel
declare TUNPORT                 #The Port to use for the reverse tunnel
#Notification Parameters
declare EMAIL                   #The email address to send notifications too.

#Script Variables that are u/bin/sed by the script.  Initial values
#are calculated by the script.
declare SERIALPORT      #Track the ttyUSB port assigned to the USB-Serial Adapter
declare MODEMPORT       #Track the first ttyUSB port assined to the modem
declare MINICOMCONF     #The current minicom configuration value for the Serial adapter ttyUSB port
declare PPPDCONF        #The current pppd configuration value for the Modem ttyUSB port
declare COUNT           #Counter Variable for Ping Test
declare PIDOFSSH        #U/bin/sed to shut down SSH Tunnel

#----------------------------------------------------------


#Gathering ports and reconfiguring via script makes the
#script more portable than configuring udev to explicity
#define ports.  It's also easier for novice administrators.

#----------------------------------------------------------

#Collect the configuration options from the Configuration file

#Hardware Parameters
SERIALSTR=`/bin/cat /home/pi/oobm.conf | /bin/grep SERIALSTR | /bin/sed -n -e s/^.*=//p`
MODEMSTR=`/bin/cat /home/pi/oobm.conf | /bin/grep MODEMSTR | /bin/sed -n -e s/^.*=//p`
MINICOMFILE=`/bin/cat /home/pi/oobm.conf | /bin/grep MINICOMFILE | /bin/sed -n -e s/^.*=//p`

#PPP Connection Parameters
PPPDSCRIPT=`/bin/cat /home/pi/oobm.conf | /bin/grep PPPDSCRIPT | /bin/sed -n -e s/^.*=//p`
PPPDPATH=`/bin/cat /home/pi/oobm.conf | /bin/grep PPPDPATH | /bin/sed -n -e s/^.*=//p`
PPPBUPATH=`/bin/cat /home/pi/oobm.conf | /bin/grep PPPBUPATH | /bin/sed -n -e s/^.*=//p`
TESTIP=`/bin/cat /home/pi/oobm.conf | /bin/grep TESTIP | /bin/sed -n -e s/^.*=//p`

#SSH Reverse Tunnel Parameters
PRIVKEY=`/bin/cat /home/pi/oobm.conf | /bin/grep PRIVKEY | /bin/sed -n -e s/^.*=//p`
REMOTEUID=`/bin/cat /home/pi/oobm.conf | /bin/grep REMOTEUID | /bin/sed -n -e s/^.*=//p`
SSHIP=`/bin/cat /home/pi/oobm.conf | /bin/grep SSHIP | /bin/sed -n -e s/^.*=//p`
TUNPORT=`/bin/cat /home/pi/oobm.conf | /bin/grep TUNPORT | /bin/sed -n -e s/^.*=//p`

#Notification Parameters
EMAIL=`/bin/cat /home/pi/oobm.conf | /bin/grep EMAIL | /bin/sed -n -e s/^.*=//p`

#----------------------------------------------------------

#Tell the Syslog service we're starting
/usr/bin/logger "OoBM Starting..."

#Gather the ports that the devices were discovered on
SERIALPORT=`/bin/dmesg | /bin/grep $SERIALSTR | /bin/grep -o "ttyUSB."`
MODEMPORT=`/bin/dmesg | /bin/grep "$MODEMSTR" | /bin/grep -m 1 -o "ttyUSB."`

#Print Parameters to screen to debug script
/usr/bin/printf "Values for configuration File Changes:\n"
/usr/bin/printf "SERIALPORT: $SERIALPORT\n"
/usr/bin/printf "MODEMPORT: $MODEMPORT\n"

#----------------------------------------------------------

#Modify Minicom port configuration as neccasary
#Collect the current configuration value
MINICOMCONF=`/bin/cat $MINICOMFILE | /bin/grep -o "ttyUSB."`

#Print Parameters to screen to debug script
/usr/bin/printf "MINICOMCONF: $MINICOMCONF\n"

#Compare current Minicom configuration with actual hardware
#If they don't match change the configuration
if [ $MINICOMCONF != $SERIALPORT ]; then

        #If the original configuration was not backed up, do it
        if [ ! -f "$MINICOMFILE.bak" ]; then
                /usr/bin/logger "OoBM Backing up original Minicom Config"
                /bin/cp "$MINICOMFILE $MINICOMFILE.bak"
        fi

        #Parse the file with SED, replace the port and save as new file
        /usr/bin/logger "OoBM Configuring up Minicom Config"
        /bin/cat $MINICOMFILE | /bin/sed s/ttyUSB./$SERIALPORT/ > $MINICOMFILE.new
        #Move edited file to config and clean up
        /bin/cp $MINICOMFILE.new $MINICOMFILE
        /bin/rm $MINICOMFILE.new
fi

#----------------------------------------------------------

#Modify PPPD port configuration as neccasary
#Collect the current configuration value
PPPDCONF=`/bin/cat $PPPDPATH$PPPDSCRIPT | /bin/grep -o "ttyUSB."`

#Print Parameters to screen to debug script
/usr/bin/printf "PPPDCONF: $PPPDCONF\n"

#Compare current PPPD configuration with actual hardware
#If they don't match change the configuration
if [ $PPPDCONF != $MODEMPORT ]; then

        #If the original configuration was not backed up, do it
        if [ ! -f "$PPPDBUPATH$PPPDSCRIPT.bak" ]; then
                /usr/bin/logger "OoBM Backing up original PPP Config"
                /bin/cp $PPPDPATH$PPPDSCRIPT $PPPDBUPATH$PPPDSCRIPT.bak
        fi
        #Parse the file with SED, replace the port and save as new file
        /usr/bin/logger "OoBM Configuring up PPP Config"
        /bin/cat $PPPDPATH$PPPDSCRIPT | /bin/sed s/ttyUSB./$MODEMPORT/ > $PPPDBUPATH$PPPDSCRIPT.new
        #Move edited file to config
        /bin/cp $PPPDBUPATH$PPPDSCRIPT.new $PPPDPATH$PPPDSCRIPT
        /bin/rm $PPPDBUPATH$PPPDSCRIPT.new
fi

#----------------------------------------------------------

#Start pppd
/usr/bin/printf "\n\nStarting PPP Connection to Cell Network:\n"
/usr/bin/logger "OoBM Starting PPP Connection"
/sbin/ifup ppp0

#Pause Script until Cell Network Comes Up
COUNT=0

until test $COUNT -eq 1 ; do
        COUNT=$( /bin/ping -c 1 $TESTIP | /bin/grep icmp* | wc -l )
        /bin/sleep 5
done
/usr/bin/printf "Connection to cell netork established.\n"
#----------------------------------------------------------

#start SSH reverse tunnel is up
#Print SSH Tunnel Parameters to screen for Debugging
/usr/bin/printf "\n\nSSH Tunnel Parms\n"
/usr/bin/printf "Tunnel Port: $TUNPORT\n"
/usr/bin/printf "Private Key File: $PRIVKEY\n"
/usr/bin/printf "Remote UID: $REMOTEUID\n"
/usr/bin/printf "SSH Server IP: $SSHIP\n"
/usr/bin/printf "\n\n"
/usr/bin/logger "OoBM Starting Reverse SSH Tunnel"
/usr/bin/ssh -f -N -oStrictHostKeyChecking=no -oServerAliveInterval=10 -oServerAliveCountMax=3 -R "$TUNPORT:localhost:22" -i $PRIVKEY "$REMOTEUID@$SSHIP"

#----------------------------------------------------------

#send email notification that OoBM is ready
/usr/bin/logger "OoBM Emailing Connection Up Status"
/bin/echo " SSH Reverse Tunnel Established. Use the 'ssh pi@localhost -p $TUNPORT' command on Home Server." | /usr/bin/mail -s "SSH Established" $EMAIL

exit 0

