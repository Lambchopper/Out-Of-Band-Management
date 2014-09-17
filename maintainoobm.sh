#!/bin/bash

#----------------------------------------------------------
#
# Out of Band Management Device Maintenance script
#
# Created by: Dave Lamb
# on: 9/5/2014
#
# This script is designed to test that the tunnel and PPP
# connection are up and if not start them.
#
# printf commands in script will only display when the script
#  is run manually.  They areu/bin/sed to debug your configuration.
#----------------------------------------------------------

#Variables whose initial values are set from configuration file
#PPP Connection Parameters
declare TESTIP                  #The IP of an internet Host to test
#SSH Reverse Tunnel Parameters
declare PRIVKEY                 #The local Private Key File
declare REMOTEUID               #The User ID on the Remote (To Pi) server
declare SSHIP                   #The Remote (To Pi) serverst start the reverse Tunnel
declare TUNPORT                 #The Port to use for the reverse tunnel
#Notification Parameters
declare EMAIL                   #The email address to send notifications too.

#Script defined variables
declare COUNT                   #Verify Ping test to Internet
declare RESTARTTEST             #Count the number of Pings as PPP restarts
declare IFSTATUS                #Used to test PPP0 Interface status
declare PIDOFSSH                #Used to see if SSH is still running after PPP failure

#----------------------------------------------------------

#Collect the values from the configuration file

#PPP Connection Parameters
TESTIP=`/bin/cat /home/pi/oobm.conf | /bin/grep TESTIP | /bin/sed -n -e s/^.*=//p`

#SSH Reverse Tunnel Parameters
PRIVKEY=`/bin/cat /home/pi/oobm.conf | /bin/grep PRIVKEY | /bin/sed -n -e s/^.*=//p`
REMOTEUID=`/bin/cat /home/pi/oobm.conf | /bin/grep REMOTEUID | /bin/sed -n -e s/^.*=//p`
SSHIP=`/bin/cat /home/pi/oobm.conf | /bin/grep SSHIP | /bin/sed -n -e s/^.*=//p`
TUNPORT=`/bin/cat /home/pi/oobm.conf | /bin/grep TUNPORT | /bin/sed -n -e s/^.*=//p`

#Notifi/bin/cation Parameters
EMAIL=`/bin/cat /home/pi/oobm.conf | /bin/grep EMAIL | /bin/sed -n -e s/^.*=//p`

#----------------------------------------------------------

#Log the Connection test
/usr/bin/logger "OoBM Checking Connection status"

#----------------------------------------------------------

#Test PPP Connection
COUNT=$( /bin/ping -c 1 $TESTIP | /bin/grep icmp* | wc -l )

#If we can't ping the test IP something's wrong
if [ $COUNT != 1 ]; then
        #Log the event
        /usr/bin/logger "OoBM Internet connectivity down, Restarting PPP"

        #Restart the ppp interface
        /sbin/ifdown ppp0
        /bin/sleep 10
        /sbin/ifup ppp0

        #Pause script until Internet connectivity is established.
        RESTARTTEST=0
        COUNT=0
        until test $COUNT -eq 1 ; do
                COUNT=$( /bin/ping -c 1 $TESTIP | /bin/grep icmp* | wc -l )
                /bin/sleep 5
                ((RESTARTTEST++))

                #If it takes more than 24 Pings (120 Seconds) to connect
                #Something's not right, just reboot
                if [ $RESTARTTEST -eq 24 ]; then
                        /usr/bin/logger "OoBM Not able to re-establish Internet connectivity, Restarting Device"
                        /sbin/shutdown -r now
                fi
        done

        #If we made it here, the PPP session was restarted
        #Now reestablish the Reverse Tunnel
        #Check to see if SSH is still running if yes, terminate and reconnect
        PIDOFSSH=`/bin/pidof ssh`
        if [ $? -ge 0 ]; then
                /bin/kill -s sigterm $PIDOFSSH
                /usr/bin/logger "OoBM Terminating SSH before reconnecting"
        fi

        /usr/bin/ssh -f -N -oStrictHostKeyChecking=no -oServerAliveInterval=10 -oServerAliveCountMax=3 -R "$TUNPORT:localhost:22" -i $PRIVKEY "$REMOTEUID@$SSHIP"
        /usr/bin/logger "OoBM re-established PPP and SSH Tunnel"

        #Notify users that we're back up
        /bin/echo " SSH Reverse Tunnel Re-Established. Use the 'ssh pi@localhost -p $TUNPORT' command on Home Server." | /usr/bin/mail -s "SSH Re-Established" $EMAIL
        exit 0
fi

#----------------------------------------------------------

#If we make it here, the PPP session is up
#Test to make sure the tunnel is still up too
/bin/pidof ssh
if [[ $? -ne 0 ]]; then
  /usr/bin/logger "OoBM PPP UP, SSH Tunnel Down, Re-Creating tunnel connection"
  /usr/bin/ssh -f -N -oStrictHostKeyChecking=no -oServerAliveInterval=10 -oServerAliveCountMax=3 -R "$TUNPORT:localhost:22" -i $PRIVKEY "$REMOTEUID@$SSHIP"
fi


