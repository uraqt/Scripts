#!/bin/bash
#1/20/2016 X.10.11  V10
# 1/20/2016 added onedrive
# 1/20/2016 removed Fix for long log in time, it broke wireless and removed script for adding RootCA

# looking for all netowk conections, sometime thunderbolt adapters are missed
/usr/sbin/networksetup -detectnewhardware

# Dummy package with image date and OS
TD=`date +"%Y-%m-%d"`
OS=10.11
touch /Library/Application\ Support/JAMF/Receipts/"$OS Imaged $TD".pkg

Sleep 5

## Lock down the login window starts green screen
icon="/Users/Shared/CTGDIR.jpg"

/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon $icon -fullScreenIcon &

# Waiting for user to load.

sleep 20

# Getting username
SN=`ls /Users | grep -v Shared | grep -v .localized | grep -v .DS_Store`

sleep 5

# Adds user to the admin group based short name.
sudo dseditgroup -o edit -a $SN -t user admin

sleep 10

# Stopping syslog to edit
#sudo launchctl unload /System/Library/LaunchDaemons/com.apple.syslogd.plist

#Adding sshd module to syslog need for full CIS syslog fowarding
#syslog -module com.openssh.sshd enable 1

# Restarting syslog
#sudo launchctl load /System/Library/LaunchDaemons/com.apple.syslogd.plist

# Creating machine name

# Getting Hardware type
HW=`sysctl hw.model |cut -c9-21| sed 's/[0-9 : . ,]*//g'`

if [[ "$HW" == "MacBookPro" ]]; then
MCN=$SN-mbp
elif [[ "$HW" == "MacBookAir" ]]; then
MCN=$SN-mba
else
MCN=$SN-ambp
fi

# unbinding from AD
sudo dsconfigad -remove -u XXXX -p XXXXXXX

sleep 20

# Replacing computer name
scutil --set HostName $MCN
scutil --set ComputerName $MCN
scutil --set LocalHostName $MCN

Sleep 20

## Bind to AD from jamf

/usr/local/bin/jamf bind -type ad  -domain 'jnpr.net' -username "XXXXXXXXX" -passhash "XXXXX" -ou "CN=Computers,DC=jnpr,DC=net" -mountStyle smb -uid "uidNumber" -userGID "gidNumber" -cache -multipleDomains -localHomes -shell none

sleep 30

# Event to install back up
/usr/local/bin/jamf policy -event BU1

# Creating AD flag for Mac Mailing list
dscl -u XXXXXXXXX -P XXXXXXX /Active\ Directory/JNPR/All\ Domains -append /Users/$SN XXXXX XXXX

# creating AD Flag for Mac Machine group
dscl -u XXXXXXXXX -P XXXXXXXX /Active\ Directory/JNPR/All\ Domains -append /Computers/$MCN XXXXXX XXXXXX

# Computer wide settings CIS and InfoSec
defaults write /Library/Preferences/com.apple.RemoteManagement LoadRemoteManagementMenuExtra -bool True
defaults write /Library/Preferences/com.apple.Bluetooth BluetoothAutoSeekHIDDevices -bool False
defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -bool False
defaults write /Library/Preferences/com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool True
defaults write /Library/Preferences/com.apple.alf globalstate -int 1 
defaults write /Library/Preferences/.GlobalPreferences PMPrintingExpandedStateForPrint -bool TRUE
defaults write /Library/Preferences/com.apple.driver.AppleIRController DeviceEnabled -bool no
defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool no
defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool no
defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName
defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo IPAddress
defaults write /Library/Preferences/com.apple.loginwindow Hide500Users -bool True


# Set screen sleep 20 min CIS and InfoSec.
sudo pmset -b displaysleep 20
sudo pmset -c displaysleep 20

# Set wake for access off CIS and InfoSec.
sudo pmset -c womp 0

# Getting username
velo=`ls /Users | grep -v admin | grep -v Shared | grep -v .localized | grep -v .DS_Store`

# Run Recon to update JSS record with user name
/usr/local/bin/jamf recon -endUsername $velo

# Setting ARD menuextra on CIS and InfoSec.
System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setmenuextra -menuextra yes

# CIS 2.8 Enable Secure Keyboard Entry in terminal.app
/usr/libexec/PlistBuddy -c "add SecureKeyboardEntry bool True" /Users/$velo/Library/Preferences/com.apple.Terminal.plist

# EmptyTrashSecurely CIS and InfoSec.
/usr/libexec/PlistBuddy -c "add EmptyTrashSecurely bool True" /Users/$velo/Library/Preferences/com.apple.finder.plist

# Setting bottom left corner to start screensver CIS and InfoSec.
/usr/libexec/PlistBuddy -c "add wvous-bl-corner integer 5" /Users/$velo/Library/Preferences/com.apple.dock.plist
/usr/libexec/PlistBuddy -c "add wvous-bl-modifier integer 0" /Users/$velo/Library/Preferences/com.apple.dock.plist

# Setting Juniper desktop
rm /Users/$velo/Library/Preferences/com.apple.desktop.plist
/usr/libexec/PlistBuddy -c "add Background:default:ImageFilePath string /Library/Desktop Pictures/Juniper 1.jpg" /Users/$velo/Library/Preferences/com.apple.desktop.plist

# Setting keyboard to tab all 
/usr/libexec/PlistBuddy -c "add AppleKeyboardUIMode integer 2" /Users/$velo/Library/Preferences/.GlobalPreferences.plist

# Getting UUID for byhost plists
UUID=`ioreg -rd1 -c IOPlatformExpertDevice | grep -i "UUID" | cut -c27-62 | awk {'print toupper()'}`

# Setting byhost to turn off auto 802.1X -network team Apple 802.1X is differnt than Juniper 802.1X
/usr/libexec/PlistBuddy -c "Add EthernetAutoConnect bool NO" /Users/$velo/Library/Preferences/ByHost/com.apple.network.eapolcontrol.$UUID.plist

# Activates the show all file extensions CIS and InfoSec.
/usr/libexec/PlistBuddy -c "add AppleShowAllExtensions bool True" /Users/$velo/Library/Preferences/.GlobalPreferences.plist

# Activates OneDrive for Business
#/usr/libexec/PlistBuddy -c "add DefaultToBusinessFRE bool True" /Users/$velo/Library/Preferences/com.microsoft.OneDrive-mac
#/usr/libexec/PlistBuddy -c "add EnableAddAccounts bool True" /Users/$velo/Library/Preferences/com.microsoft.OneDrive-mac

# Setting Outlook as default Mail app..
# Create the LSHandlers array
/usr/libexec/plistbuddy -c "add:LSHandlers array" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
# Set default for mailto links
/usr/libexec/plistbuddy -c "add:LSHandlers:0:LSHandlerURLScheme string mailto" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
/usr/libexec/plistbuddy -c "add:LSHandlers:0:LSHandlerRoleAll string com.microsoft.outlook" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
# Set Outlook as default for email
/usr/libexec/plistbuddy -c "add:LSHandlers:1:LSHandlerContentType string com.apple.mail.email" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
/usr/libexec/plistbuddy -c "add:LSHandlers:1:LSHandlerRoleAll string com.microsoft.outlook" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
/usr/libexec/plistbuddy -c "add:LSHandlers:2:LSHandlerContentType string com.microsoft.outlook16.email-message" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plistcom.apple.LaunchServices.plist
/usr/libexec/plistbuddy -c "add:LSHandlers:2:LSHandlerRoleAll string com.microsoft.outlook" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist

# Set Outlook as default for .vcard
/usr/libexec/plistbuddy -c "add:LSHandlers:3:LSHandlerContentType string public.vcard" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
/usr/libexec/plistbuddy -c "add:LSHandlers:3:LSHandlerRoleAll string com.microsoft.outlook" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist

# Set Outlook as default for .ics files
/usr/libexec/plistbuddy -c "add:LSHandlers:4:LSHandlerContentType string com.apple.ical.ics" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
/usr/libexec/plistbuddy -c "add:LSHandlers:4:LSHandlerRoleAll string com.microsoft.outlook" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist

# Set Outlook as default calendar app
/usr/libexec/plistbuddy -c "add:LSHandlers:5:LSHandlerContentType string com.microsoft.outlook16.icalendar" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plistcom.apple.LaunchServices.plist
/usr/libexec/plistbuddy -c "add:LSHandlers:5:LSHandlerRoleAll string com.microsoft.outlook" /Users/$velo/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist

# Install cert
#security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /Users/Shared/certnew.cer

# Setting Wi-Fi to linklocal for Outlook Auth issues... 
networksetup -setv6linklocal Wi-Fi


# Event to create/add admin account
/usr/local/bin/jamf policy -event AA

sleep 10

# Setting DHCP client ID
BCN=`scutil --get HostName`

NE=`/usr/sbin/networksetup -listallhardwareports | grep -A 1 Wi-Fi | grep Device | cut -c 9-12`

if [[ "$NE" == "en1" ]]; then
networksetup -setdhcp Ethernet "$BCN"
networksetup -setdhcp Wi-Fi "$BCN"
elif [[ "$NE" == "en0" ]]; then
networksetup -setdhcp Wi-Fi "$BCN"
networksetup -setdhcp "Thunderbolt Ethernet" "$BCN"
else
echo error
fi

# Access warning for the command line, creensaver and login window (CIS Requirement 1.2.3)
echo "This system is the property of Juniper Networks and is intended for Juniper business use only.  To protect its information resources, Juniper monitors its systems and infrastructure.  See the Acceptable Use Policy available on the corporate intranet for more information." >> "/etc/motd"

# Set SSH defaults to be more stringent (CIS 1.4.14.8)
# Back up "/etc/sshd_config"
cp "/etc/sshd_config" "/etc/sshd_config-$(date +%Y-%m-%d)"

# Modify /etc/sshd_config CIS
perl -p -i -e 's/\#PermitRootLogin\ yes/PermitRootLogin\ no/g' "/etc/sshd_config"
perl -p -i -e 's/\#MaxAuthTries\ 6/MaxAuthTries\ 4/g' "/etc/sshd_config"
perl -p -i -e 's/\#ClientAliveInterval\ 0/ClientAliveInterval\ 300/g' "/etc/sshd_config"
perl -p -i -e 's/\#ClientAliveCountMax\ 3\ yes/ClientAliveCountMax\ 0/g' "/etc/sshd_config"
perl -p -i -e 's/\#LogLevel INFO/LogLevel\ VERBOSE/g' "/etc/sshd_config"

# Back up "/etc/newsyslog.conf"
cp "/etc/newsyslog.conf" "/etc/newsyslog.conf-$(date +%Y-%m-%d)"

# Increase the retention time for system.log and secure.log (CIS Requirement 1.7.1I)
perl -p -i -e 's/\/var\/log\/wtmp.*$/\/var\/log\/wtmp   \t\t\t640\ \ 31\    *\t\@hh24\ \J/g' "/etc/newsyslog.conf"
perl -p -i -e 's/appfirewall.log file_max=5M all_max=50M/appfirewall.log rotate=seq compress file_max=10M ttly=31/g' "/etc/asl.conf"
#system.log change
perl -p -i -e 's/file_max=5M all_max=50M/file_max=10M ttly=31/g' "/etc/asl.conf"
perl -p -i -e 's/format=bsd/format=bsd rotate=seq compress file_max=10M ttly=31/g' "/etc/asl/com.apple.install"

# Adding jnpr pulse config file
/Applications/Pulse\ Secure.app/Contents/Plugins/JamUI/jamCommand -importfile /Users/Shared/Components.jnprpreconfig


# Removing .plist so byhost .plist load
rm /Users/$velo/Library/Preferences/com.apple.systemuiserver.plist

# Removing installer .pkg files
rm -r /Users/Shared/certnew.cer

# Removing Launchds
rm /Library/LaunchDaemons/com.juniper.admin.plist
rm /Library/LaunchDaemons/com.juniper.config.plist


# Run Recon to update JSS record with the new computer name created in the admin script
sudo /usr/local/bin/jamf recon

Sleep 10

# Install RSA
installer -allowUntrusted -pkg /Users/Shared/RSA/RSASecurIDTokenAutoMac412x64.pkg -target /

Sleep 5

# Access warning for the FV2 per InfoSec.
defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "This system is the property of Juniper Networks and is intended for Juniper business use only.  To protect its information resources, Juniper monitors its systems and infrastructure.  See the Acceptable Use Policy available on the corporate intranet for more information."

## Fix for Wi-Fi remembering networks. For long log in times Casper checking for JSS
#perl -p -i -e 's|/usr/sbin/jamf hideRestore|/usr/sbin/jamf hideRestore\n\n/usr/sbin/networksetup -setnetworkserviceenabled Wi-Fi on|g' /Library/Application\ Support/JAMF/ManagementFrameworkScripts/loginhook.sh

#perl -p -i -e 's|\#!/bin/sh|#!/bin/sh\n\n/usr/sbin/networksetup -setnetworkserviceenabled Wi-Fi off|g' /Library/Application\ Support/JAMF/ManagementFrameworkScripts/logouthook.sh



# CIS 5.6 Require password for system wide system prefs.
security authorizationdb read system.preferences > /tmp/system.preferences.plist
/usr/libexec/PlistBuddy -c "Set :shared false" /tmp/system.preferences.plist
security authorizationdb write system.preferences < /tmp/system.preferences.plist

# CIS 3.3 audit_control flags setting. Steve Green approved ^-fa,^-fc,^-cl changes
perl -p -i -e 's|flags:lo,aa|flags:lo,aa,ad,fd,fm,-all,^-fa,^-fc,^-cl|g' /private/etc/security/audit_control
perl -p -i -e 's|filesz:2M|filesz:10M|g' /private/etc/security/audit_control
perl -p -i -e 's|expire-after:10M|expire-after: 30d |g' /private/etc/security/audit_control

# Changing ~ home read persions per CIS to 700
chmod 700 /Users/$velo
chmod 700 /Users/admin

Sleep 5

# Setting Homepage and NewWindowBehavior - CTG
su $velo -c python - <<END
import CoreFoundation
CoreFoundation.CFPreferencesSetAppValue("NewWindowBehavior", "0",  "com.apple.Safari")
CoreFoundation.CFPreferencesAppSynchronize("com.apple.Safari")
CoreFoundation.CFPreferencesSetAppValue("BuiltInBookmarks", "http://core.juniper.net",  "com.apple.Safari")
CoreFoundation.CFPreferencesAppSynchronize("com.apple.Safari")
CoreFoundation.CFPreferencesSetAppValue("HomePage", "http://core.juniper.net",  "com.apple.Safari")
CoreFoundation.CFPreferencesAppSynchronize("com.apple.Safari")
END

#Installing profile to block system prefs Profiles.
profiles -I -F /Users/Shared/Profile.mobileconfig


# CIS 2.10 disabling core dumps
launchctl limit core 0

# Event to start casper FDE
/usr/local/bin/jamf policy -event FDE


# Appending the following line to syslog.conf for syslog fowarding
#echo "*.*   @172.24.0.216:9997" >> /etc/syslog.conf

# Starting and stoping syslog.plist for syslog fowarding
#launchctl unload /System/Library/LaunchDaemons/com.apple.syslogd.plist
#sleep 3
#launchctl load -w /System/Library/LaunchDaemons/com.apple.syslogd.plist


# Removing profile in ~/Shared to block system prefs Profiles.
rm /Users/Shared/Profile.mobileconfig

# Deleting this script
rm $0

# Removing pulse config file - per network team file has passwords
rm /Users/Shared/Components.jnprpreconfig

# Removing RSA install files
rm -rf /Users/Shared/RSA

Sleep 30

# Removing CTG branding - CTG
rm /Users/Shared/CTGDIR.jpg

# reboot
sudo shutdown -r now



