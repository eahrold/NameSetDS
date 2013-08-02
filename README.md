###NameSetDS
We use Deploystudio for our deployment across the board.  So there's not a computer that dosen't get registered with.  However we were finding that DS's setcomputer name workflow task was a bit unreliable, and did nothing to set the LocalHostName.  That's where this tool comes in.  On a periodic basis this queries the DS Server and resets the Computer Name and LocalHost name based on the values in the DSdb.

###Setup
install the binary in /usr/local/sbin

There are two keys that need to be set in the Preference file, serverName and userAuth.  
The Server Name should be the full url including port, which is 60443 by default.
The User Auth is a user that has access the the DS runtime.   

**These four commands should take care of it**

	$ sudo defaults write /Library/Preferences/com.aapps.NameSetDS serverName http(s)://your.server.com:60443
	$ HASHEDPASS = $(python -c 'import base64; print "Basic %s" % base64.b64encode("username:password")')  
	$ sudo defaults write /Library/Preferences/com.aapps.NameSetDS userAuth $HASHEDPASS  
	$ sudo chmod 644 /Library/Preferences/com.aapps.NameSetDS
_*For added security you can specify /var/root/Library/Preferences/com.aapps.NameSetDS as the defaults location_
_*For You can also used MCX to deploy defaults, either profile manager or a directory server_
	
 	
**Then make a LaunchDaemon to run it periodically**

	$ sudo defaults write /Library/LaunchDaemons/com.aapps.NameSetDS Label com.aapps.NameSetDS
	$ sudo defaults write /Library/LaunchDaemons/com.aapps.NameSetDS ProgramArguments -array /usr/local/sbin/NameSetDS
	$ sudo defaults write /Library/LaunchDaemons/com.aapps.NameSetDS StartInterval -int 3600
	$ sudo chmod 644 /Library/LaunchDaemons/com.aapps.NameSetDS.plist 
	$ sudo launchctl load /Library/LaunchDaemons/com.aapps.NameSetDS.plist
	
