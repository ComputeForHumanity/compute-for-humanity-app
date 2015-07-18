//
//  AppDelegate.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 5/6/15.
//  Copyright (c) 2015 Jacob Evelyn. All rights reserved.
//

import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var donationStatus: NSMenuItem!
    @IBOutlet weak var miningStatus: NSMenuItem!
    @IBOutlet weak var aboutPanel: NSPanel!
    @IBOutlet weak var downloadWindow: NSWindow!
    
    let version = "1.1"
    let uuid: String = NSUUID().UUIDString
    
    // The status bar item for this menu.
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    
    let task = NSTask() // The miner process.
    
    let baseServerUrl: String = "http://www.computeforhumanity.org"
    
    var resumeTimer: NSTimer = NSTimer()
    
    // We will only mine (and we will only have the
    // resumeTimer alive) when the thermals are cool
    // enough and the user hasn't paused mining.
    var userPausedMining = false
    var coolEnoughToMine = false

    // Fired when the application launches.
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        initializeIcon()
        
        // Set the application to launch at startup.
        if !applicationIsInStartUpItems() {
            toggleLaunchAtStartup()
        }
        
        registerThermalStateListener()
        thermalStateChanged()
        initializeMiner()
        checkForUpdates()
        sendHeartbeat()
    }
    
    // Initialize the status bar icon for this app.
    func initializeIcon() {
        let icon = NSImage(named: "statusIcon")
        icon?.setTemplate(true)
        
        statusItem.image = icon
        statusItem.menu = statusMenu
    }
    
    // Register the app to listen for thermal state changes from the OS
    // and respond to them with the thermalStateChanged() function.
    func registerThermalStateListener() {
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("thermalStateChanged"),
            name: NSProcessInfoThermalStateDidChangeNotification,
            object: nil
        )
    }
    
    // Update our internal status storing our thermal state, and
    // begin/resume/stop mining as appropriate.
    func thermalStateChanged() {
        let state = NSProcessInfo.processInfo().thermalState
        coolEnoughToMine = (state == NSProcessInfoThermalState.Nominal)
        
        // We have to call this in the main thread so the UI and timer
        // will update correctly.
        dispatch_async(dispatch_get_main_queue(), {
            if !self.coolEnoughToMine && !self.userPausedMining {
                self.miningStatus.title = "Status: Paused (computer too warm)"
            }
            
            self.initializeOrInvalidateMinerResumeTimer()
        })
    }
    
    // Initialize the creation and scheduling of the miner process.
    func initializeMiner() {
        // Get the fully qualified path to the miner.
        let bundle = NSBundle.mainBundle()
        let fullyQualifiedMiner = bundle.pathForResource("minerd", ofType: nil)!
        
        // Use `nice` to give mining the lowest CPU scheduling priority.
        task.launchPath = "/usr/bin/nice"
        task.arguments = [
            "-n", "20", // Use highest niceness for lowest CPU scheduling priority.
            fullyQualifiedMiner,
            "--threads=1", "--engine=1", // More hashes, low output.
            "--quiet", // Don't output hash rates.
            "--url=stratum+tcp://stratum.nicehash.com:3341",
            "--user=12CbZWfSB5TESmFwiYs4WJRZtJyi9hBPNz", "--pass=x"
        ]
        
        // Tell OS X to treat this as a low-priority background task.
        task.qualityOfService = NSQualityOfService.Background
        
        // Start the process and immediately pause it. The resumeTimer will kick it
        // off when appropriate.
        task.launch()
        pauseMining()
    }
    
    // Check to see if there is a newer version of the app. If so,
    // display the download window.
    func checkForUpdates() {
        let urlPath: String = baseServerUrl + "/version"
        var url: NSURL = NSURL(string: urlPath)!
        var request: NSURLRequest = NSURLRequest(URL: url)
        let queue: NSOperationQueue = NSOperationQueue()
        
        NSURLConnection.sendAsynchronousRequest(
            request,
            queue: queue,
            completionHandler: { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
                let httpResponse = response as? NSHTTPURLResponse
                
                if error == nil && httpResponse != nil && httpResponse?.statusCode == 200 && data != nil {
                    let serverVersion: NSString = NSString(data: data!, encoding: NSUTF8StringEncoding)!
                    let currentVersion = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String
                    
                    if currentVersion != serverVersion {
                        dispatch_async(dispatch_get_main_queue(), {
                            NSApplication.sharedApplication().activateIgnoringOtherApps(true)
                            self.downloadWindow.makeKeyAndOrderFront(self)
                        })
                    }
                }
            }
        )
    }

    // Initialize the miner resume timer, as long as we're
    // not paused and the thermals are okay.
    func initializeOrInvalidateMinerResumeTimer() {
        // Do nothing if the user's paused or the thermals
        // are too warm.
        if coolEnoughToMine && !userPausedMining {
            // Every 60 seconds, resume the suspended miner process.
            resumeTimer = NSTimer.scheduledTimerWithTimeInterval(
                60,
                target: self,
                selector: Selector("resumeMining"),
                userInfo: nil,
                repeats: true
            )
            resumeTimer.tolerance = 10 // We're not picky about timing.
            
            miningStatus.title = "Status: Running"
        } else if resumeTimer.valid {
            resumeTimer.invalidate()
        }
    }

    // Fired when the app is terminated. Shuts down the miner process.
    func applicationWillTerminate(aNotification: NSNotification) {
        terminateMiner()
    }
    
    // Send a heartbeat to the server, for live miner
    // counts and statistics purposes.
    func sendHeartbeat() {
        let urlPath: String = baseServerUrl + "/heartbeat?id=" + uuid
        var url: NSURL = NSURL(string: urlPath)!
        var request: NSURLRequest = NSURLRequest(URL: url)
        let queue: NSOperationQueue = NSOperationQueue()
        
        NSURLConnection.sendAsynchronousRequest(
            request,
            queue: queue,
            completionHandler: { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
                let httpResponse = response as? NSHTTPURLResponse
                
                if error == nil && httpResponse != nil && httpResponse?.statusCode == 200 && data != nil {
                    let donated: NSString = NSString(data: data!, encoding: NSUTF8StringEncoding)!
                    dispatch_async(dispatch_get_main_queue(), {
                        self.donationStatus.title = "\(donated) donated so far!"
                    })
                }
            }
        )
    }
    
    // Resume the suspended miner process.
    func resumeMining() {
        // Here we resume the miner process and pause it in ten seconds.
        let pauseTimer = NSTimer.scheduledTimerWithTimeInterval(
            10,
            target: self,
            selector: Selector("pauseMining"),
            userInfo: nil,
            repeats: false
        )
        pauseTimer.tolerance = 1 // We're not picky about timing.
        
        task.resume() // Let's go!
        sendHeartbeat()
    }
    
    // Suspend the miner process.
    func pauseMining() {
        task.suspend()
    }
    
    // Kill the miner process. This is used before we kill the
    // parent app.
    func terminateMiner() {
        task.terminate()
        task.waitUntilExit()
    }

    // Fired when the "About Compute for Humanity" item is selected.
    @IBAction func aboutClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        aboutPanel.makeKeyAndOrderFront(sender)
    }
    
    // Fired when the "Pause" item is checked/unchecked.
    @IBAction func pauseResumeClicked(sender: NSMenuItem) {
        if sender.state == NSOnState {
            userPausedMining = false
            sender.state = NSOffState
        } else {
            userPausedMining = true
            sender.state = NSOnState
            miningStatus.title = "Status: Paused"
        }
        
        initializeOrInvalidateMinerResumeTimer()
    }
    
    // Fired when the "Quit" item is selected.
    @IBAction func quitClicked(sender: NSMenuItem) {
        terminateMiner()
        NSApplication.sharedApplication().terminate(nil)
    }
    
    // Fired when the website link button within the About panel is selected.
    @IBAction func linkClicked(sender: NSButton) {
        let url = NSURL(string: baseServerUrl)
        NSWorkspace.sharedWorkspace().openURL(url!)
    }
    
    // Fired when the download button is clicked in the download window
    // (which appears when an update is needed).
    @IBAction func downloadClicked(sender: NSButton) {
        let url = NSURL(string: baseServerUrl + "/download")
        NSWorkspace.sharedWorkspace().openURL(url!)
        downloadWindow.close()
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////
    // Note: The below code is modified from: http://stackoverflow.com/questions/26475008 //
    ////////////////////////////////////////////////////////////////////////////////////////
    
    // Return true if this app is in the system's list of startup items.
    func applicationIsInStartUpItems() -> Bool {
        return (itemReferencesInLoginItems().existingReference != nil)
    }
    
    // Returns a list of references to login items for the current user.
    func itemReferencesInLoginItems() -> (existingReference: LSSharedFileListItemRef?, lastReference: LSSharedFileListItemRef?) {
        var itemUrl: UnsafeMutablePointer<Unmanaged<CFURL>?> = UnsafeMutablePointer<Unmanaged<CFURL>?>.alloc(1)
        if let appUrl: NSURL = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
            let loginItemsRef = LSSharedFileListCreate(
                nil,
                kLSSharedFileListSessionLoginItems.takeRetainedValue(),
                nil
                ).takeRetainedValue() as LSSharedFileListRef?
            if loginItemsRef != nil {
                let loginItems: NSArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
                if(loginItems.count > 0)
                {
                    let lastItemRef: LSSharedFileListItemRef = loginItems.lastObject as! LSSharedFileListItemRef
                    for var i = 0; i < loginItems.count; ++i {
                        let currentItemRef: LSSharedFileListItemRef = loginItems.objectAtIndex(i) as! LSSharedFileListItemRef
                        let currentItemUrl = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil).takeRetainedValue()
                        if appUrl.isEqual(currentItemUrl) {
                            return (currentItemRef, lastItemRef)
                        }
                    }
                    // The application was not found in the startup list.
                    return (nil, lastItemRef)
                }
                else
                {
                    let addatstart: LSSharedFileListItemRef = kLSSharedFileListItemBeforeFirst.takeRetainedValue()
                    
                    return(nil,addatstart)
                }
            }
        }
        return (nil, nil)
    }
    
    // Toggles whether or not this program is launched at startup.
    func toggleLaunchAtStartup() {
        let itemReferences = itemReferencesInLoginItems()
        let shouldBeToggled = (itemReferences.existingReference == nil)
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
            ).takeRetainedValue() as LSSharedFileListRef?
        if loginItemsRef != nil {
            if shouldBeToggled {
                if let appUrl: CFURLRef = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
                    LSSharedFileListInsertItemURL(
                        loginItemsRef,
                        itemReferences.lastReference,
                        nil,
                        nil,
                        appUrl,
                        nil,
                        nil
                    )
                }
            } else {
                if let itemRef = itemReferences.existingReference {
                    LSSharedFileListItemRemove(loginItemsRef,itemRef);
                }
            }
        }
    }
}

