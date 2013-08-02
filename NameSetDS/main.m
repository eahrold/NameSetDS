//
//  main.m
//  NameSetDS
//
//  Created by Eldon Ahrold on 8/1/13.
//  Copyright (c) 2013 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

CFStringRef bundleID = CFSTR("com.aapps.NameSetDS");



NSString* getSerialNumber()
{
    
    CFTypeRef CFSTRSeralNumber = nil;
    NSString *sn = nil;
    
    // start if off
    io_service_t platformExpert =
        IOServiceGetMatchingService(kIOMasterPortDefault,
                                    IOServiceMatching("IOPlatformExpertDevice"));
    
    // call it up 
    if (platformExpert){
        CFSTRSeralNumber =
            IORegistryEntryCreateCFProperty(platformExpert,
                                            CFSTR(kIOPlatformSerialNumberKey),
                                            kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
    }
    
    // switch it out
    if(CFSTRSeralNumber){
        sn = [[NSString alloc] initWithFormat:@"%@",CFSTRSeralNumber];
        CFRelease(CFSTRSeralNumber);
    }
    return sn;
}

NSString* getMacAddress()
{
    NSString* mac = nil;
    return mac;
}

NSString* queryServer(NSString* dsid,NSString* serverName,NSString* authValue)
{
    NSError* error = nil;
    NSURLResponse* response = nil;
    
    
    NSString* URL = [NSString stringWithFormat:@"%@/computers/get/entry?id=%@",serverName,dsid];
    
    // Create the request.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
    
    // set as GET request
    request.HTTPMethod = @"GET";
    
    // set header fields
    [request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    
    // Create url connection and send request
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSDictionary* dict;
    
    // if success then convert the data to a NSDictionary
    if(!error){
        NSString* errorDesc = nil;
        NSPropertyListFormat plist;
        dict = (NSDictionary*)[NSPropertyListSerialization
                               propertyListFromData:data
                               mutabilityOption:NSPropertyListMutableContainersAndLeaves
                               format:&plist
                               errorDescription:&errorDesc];
    }else{
        NSLog(@"%@",[error localizedDescription]);
        return nil;
        
    }
    
    // DeployStudio sends a nested dictionary back so we need to drill down
    dict = [dict objectForKey:dsid];
    NSString* computerName = [dict objectForKey:@"dstudio-hostname"];
    
    return computerName;
}


NSString* getNameFromServerWithSerial(NSString* serverName,NSString* authValue)
{
    NSString* computeName = nil;
    NSString* serial = getSerialNumber();
    computeName = queryServer(serial, serverName, authValue);
    NSLog(@"Using Computer Name: %@",computeName);

    return computeName;
}

NSString* getNameFromServerWithMac(NSString* serverName,NSString* authValue)
{
    NSString* computeName = nil;
    NSString* mac = getMacAddress();
    computeName = queryServer(mac, serverName, authValue);

    return computeName;

}

NSString* getNameFromServer()
{
    NSString* computerName = nil;
    
    // get the value from the managed preferences
    NSString* __weak serverName = (__bridge NSString *)(CFPreferencesCopyAppValue(CFSTR("serverName"), bundleID));
    NSString* __weak authValue = (__bridge NSString *)(CFPreferencesCopyAppValue(CFSTR("userAuth"), bundleID));
    
    if(!(serverName || authValue)){
        NSLog(@"Preferences are configured correctly.");
        return nil;
    }
    
    // first try getting the Name using computers serial number
    computerName = getNameFromServerWithSerial(serverName, authValue);
    
    // if that fails try using the mac address
    if(!computerName){
        getNameFromServerWithMac(serverName, authValue);
    }
    
    return computerName;
}


void setComputerName(NSString* computerName){
    // create the system config preference reference
    SCPreferencesRef prefs = SCPreferencesCreate(NULL,CFSTR("SystemConfiguration"), NULL);
    CFStringRef cn = (__bridge CFStringRef) computerName;
    
    // check to see wether we need to actually do anything
    NSDictionary *allSC = (__bridge NSDictionary *)SCPreferencesGetValue(prefs, kSCPrefSystem);
    NSDictionary *system = [allSC objectForKey:@"System"];
    NSDictionary *network = [allSC objectForKey:@"Network"];
    NSDictionary *hostnames = [network objectForKey:@"HostNames"];
    
    NSString *currentComputerName = [system objectForKey:@"ComputerName"];
    NSString *currentLocalHostName = [hostnames objectForKey:@"LocalHostName"];
    
    bool hasChanged = NO;
    
    // set the LocalHostName
    if(![computerName isEqualToString:currentLocalHostName]){
        hasChanged = YES;
        if(!SCPreferencesSetLocalHostName(prefs,cn))
        {
            NSLog(@"Couldn't set the LocalHost Name");
        }
    }
    
    // set the Computer Name
    if(![computerName isEqualToString:currentComputerName]){
        hasChanged = YES;
        if(!SCPreferencesSetComputerName(prefs,cn,kCFStringEncodingUTF8))
        {
            NSLog(@"Couldn't set the Computer Name");
        }
    }
    
    // and finally sync everything up
    if(hasChanged){        
        // we must commit before we apply!!
        SCPreferencesCommitChanges(prefs);
        SCPreferencesApplyChanges(prefs);
    }
       // clean up
    CFRelease(prefs);
}


int main(int argc, const char * argv[])
{
    @autoreleasepool {
        // we'll see if we have permission before moving forward
        if (!getuid() == 0){
            return 0;
        }

        NSString* cn = getNameFromServer();
        if(cn){
            setComputerName(cn);
        }
    }
    return 0;
}
