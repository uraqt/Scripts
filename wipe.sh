#!/bin/bash

#stall for dock/user login

dockStatus=$(pgrep -x Dock)

while [ "$dockStatus" == "" ]; do
  
  sleep 3
  dockStatus=$(pgrep -x Dock)
done



# User details for DEV and PROD
jamfUser="XXXXX"
jamfPass="XXXXX"


#Jamf Pro URL PROD
jamfproUrl="https://XXXXXXX.jamfcloud.com"

# getting UUID of the Mac for remove from casper
UUID=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/grep -i "UUID" | /usr/bin/cut -c27-62)

# getting the JSS ID of the mac for wipe of machine in casper has to be JSS ID
CI=$(curl -s -k -u XXXXXXX:XXXXXXXXX -H "Accept: application/xml" -H "Content-Type: application/xml" https://jnpr.jamfcloud.com/JSSResource/computers/udid/$UUID  | xmllint --xpath "/computer/general/id/text()" -)

# Opening the "wait we're checking security" message page
open /Users/Shared/Blue/Blue.app

# Delay to give the illusion that the check is running
sleep 115

# close the message page
osascript -e 'quit app "Safari"'

# Check for Password profile
if [ "$(profiles -Pv | grep "attribute: name: Passcode minLength" | cut -d ' ' -f 4-)" == "Passcode minLength" ]
    then
        
        sleep 1
        
    else
        open /Users/Shared/Red/Red.app
        sleep 60
        osascript -e 'quit app "Safari"'
        
       #API call to wipe
       /usr/bin/curl --connect-timeout 30 --request POST --user $jamfUser:$jamfPass $jamfproUrl/JSSResource/computercommands/command/EraseDevice/passcode/123456/id/$CI


fi

# returns FDE details of the machine
apicr=$(curl -s -k -u $jamfUser:$jamfPass -H "Accept: application/xml" -H "Content-Type: application/xml" $jamfproUrl/JSSResource/computers/udid/$UUID | xmllint --xpath "/computer/hardware/disk_encryption_configuration/text()" -)

		# logic that gives the thumbs up or down
        if [[ $apicr != "FDE" ]]; then
                open /Users/Shared/Red/Red.app
                sleep 60
                osascript -e 'quit app "Safari"'
                
		#API call to wipe
                /usr/bin/curl --connect-timeout 60 --request POST --user $jamfUser:$jamfPass $jamfproUrl/JSSResource/computercommands/command/EraseDevice/passcode/123456/id/$CI

        else
		open /Users/Shared/Green/Green.app
		sleep 90
                osascript -e 'quit app "Safari"'
                

#deleting computer from casper with UUID add after 1st month of prod...use we can still see logs for wiped machines
#curl -k -v -u $jamfUser:$jamfPass $jamfproUrl/JSSResource/computers/udid/$UUID -X DELETE

# Deleting this script
rm $0

rm -rf /Users/Shared/Red
rm -rf /Users/Shared/Green
rm -rf /Users/Shared/Blue
sudo rm /Library/LaunchDaemons/com.juniper.wipescript.plist

    fi


exit
