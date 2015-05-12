//
//  AppDelegate.swift
//  Compute for Humanity Menu Bar
//
//  Created by Jacob Evelyn on 5/6/15.
//  Copyright (c) 2015 Jacob Evelyn. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var aboutPanel: NSPanel!
    
    // The status bar item for this menu.
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    
    let task = NSTask() // The miner process.
    
    var resumeTimer : NSTimer = NSTimer()

    // Fired when the application launches.
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        initializeIcon()
        
        // Set the application to launch at startup.
        if !applicationIsInStartUpItems() {
            NSLog("Setting Compute for Humanity to launch at startup")
            toggleLaunchAtStartup()
        }
        
        initializeMiner()
    }
    
    // Initialize the status bar icon for this app.
    func initializeIcon() {
        let icon = NSImage(named: "statusIcon")
        icon?.setTemplate(true)
        
        statusItem.image = icon
        statusItem.menu = statusMenu
    }
    
    // Initialize the creation and scheduling of the miner process.
    func initializeMiner() {
        initializeMinerResumeTimer()
        
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
        
        // Start the process and immediately pause it. The resumeTimer will kick it
        // off in a bit.
        task.launch()
        pauseMining()
    }

    func initializeMinerResumeTimer() {
        // Every 60 seconds, resume the suspended miner process.
        resumeTimer = NSTimer.scheduledTimerWithTimeInterval(
            60,
            target: self,
            selector: Selector("resumeMining"),
            userInfo: nil,
            repeats: true
        )
        resumeTimer.tolerance = 10 // We're not picky about timing.
    }

    // Fired when the app is terminated. Shuts down the miner process.
    func applicationWillTerminate(aNotification: NSNotification) {
        terminateMiner()
    }
    
    // Resume the suspended miner process (unless we're paused).
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
        aboutPanel.makeKeyAndOrderFront(sender)
    }
    
    // Fired when the "Pause" item is checked/unchecked.
    @IBAction func pauseResumeClicked(sender: NSMenuItem) {
        if sender.state == NSOnState {
            sender.state = NSOffState
            initializeMinerResumeTimer()
        } else {
            sender.state = NSOnState
            resumeTimer.invalidate()
        }
    }
    
    // Fired when the "Quit" item is selected.
    @IBAction func quitClicked(sender: NSMenuItem) {
        terminateMiner()
        NSApplication.sharedApplication().terminate(nil)
    }
    
    // Fired when the website link button within the About panel is selected.
    @IBAction func linkClicked(sender: NSButton) {
        let url = NSURL(string: "http://www.computeforhumanity.org")
        NSWorkspace.sharedWorkspace().openURL(url!)
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
        var itemUrl : UnsafeMutablePointer<Unmanaged<CFURL>?> = UnsafeMutablePointer<Unmanaged<CFURL>?>.alloc(1)
        if let appUrl : NSURL = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
            let loginItemsRef = LSSharedFileListCreate(
                nil,
                kLSSharedFileListSessionLoginItems.takeRetainedValue(),
                nil
                ).takeRetainedValue() as LSSharedFileListRef?
            if loginItemsRef != nil {
                let loginItems: NSArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
                if(loginItems.count > 0)
                {
                    let lastItemRef: LSSharedFileListItemRef = loginItems.lastObject as LSSharedFileListItemRef
                    for var i = 0; i < loginItems.count; ++i {
                        let currentItemRef: LSSharedFileListItemRef = loginItems.objectAtIndex(i) as LSSharedFileListItemRef
                        if LSSharedFileListItemResolve(currentItemRef, 0, itemUrl, nil) == noErr {
                            if let urlRef: NSURL =  itemUrl.memory?.takeRetainedValue() {
                                if urlRef.isEqual(appUrl) {
                                    return (currentItemRef, lastItemRef)
                                }
                            }
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
                if let appUrl : CFURLRef = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
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

