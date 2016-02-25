//
//  MiningManager.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 2/7/16.
//  Copyright © 2016 Jacob Evelyn. All rights reserved.
//

// We have to subclass NSObject so our timer Selector callbacks work.
class MiningManager: NSObject {
    let dataManager: DataManager
    let requestManager: RequestManager
    
    let resumeTimerInterval: NSTimeInterval = 180 // Seconds.
    let miningTimerDurationNormal: NSTimeInterval = 20 // Seconds.
    let miningTimerDurationMoreCpu: NSTimeInterval = 60 // Seconds.
    let heartRateNormal: Int = 1
    let heartRateMoreCpu: Int = 3
    
    // Apple recommends a tolerance of 10% of the timer duration.
    let tolerancePercentage = 0.1
    
    let resumeTimerTolerance: NSTimeInterval
    let miningTimerToleranceMoreCpu: NSTimeInterval
    let miningTimerToleranceNormal: NSTimeInterval
    
    let task = NSTask() // The miner process.
    
    var miningTimerDuration: NSTimeInterval
    var miningTimerTolerance: NSTimeInterval
    var heartRate: Int
    
    // The timer that tells us when to resume mining after pausing.
    var resumeTimer: NSTimer = NSTimer()
    
    // We will only mine (and we will only have the
    // resumeTimer alive) when the thermals are cool
    // enough and the user hasn't paused mining.
    var userPausedMining = false
    var coolEnoughToMine = false
    
    // We make the initializer private so other classes must access
    // the singleton instance with the singleton instance property.
    init(dataManager: DataManager, requestManager: RequestManager) {
        self.dataManager = dataManager
        self.requestManager = requestManager
        
        // Calculate the tolerances we should use for our timers.
        resumeTimerTolerance = resumeTimerInterval * tolerancePercentage
        miningTimerToleranceNormal = miningTimerDurationNormal * tolerancePercentage
        miningTimerToleranceMoreCpu = miningTimerDurationMoreCpu * tolerancePercentage
        
        // Default our values to the normal values.
        miningTimerDuration = miningTimerDurationNormal
        miningTimerTolerance = miningTimerToleranceNormal
        heartRate = heartRateNormal
    }
    
    func initialize() {
        // Register that we listen to thermal state change events.
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: Selector("thermalStateChanged"),
            name: NSProcessInfoThermalStateDidChangeNotification,
            object: nil
        )
        
        // Make an initial read of the thermal state to set our values.
        // Note that this can trigger a heartbeat.
        thermalStateChanged()
        
        // Get the fully qualified path to the miner.
        let bundle = NSBundle.mainBundle()
        let fullyQualifiedMiner = bundle.pathForResource("ComputeForHumanityHelper", ofType: nil)!
        
        // Use `nice` to give mining the lowest CPU scheduling priority.
        task.launchPath = "/usr/bin/nice"
        task.arguments = [
            "-n", "20", // Use highest niceness for lowest CPU scheduling priority.
            fullyQualifiedMiner,
            "--threads=1", // Only use one thread.
            "--engine=1", // Produces more hashes on the machines I've tested.
            "--quiet", // Don't output hash rates.
            "--retry-pause=\(miningTimerDurationNormal / 2)", // If there's an error, retry twice/cycle.
            "--url=stratum+tcp://neoscrypt.usa.nicehash.com:3341",
            "--user=12CbZWfSB5TESmFwiYs4WJRZtJyi9hBPNz", "--pass='d=0.01'"
        ]
        
        // Tell OS X to treat this as a low-priority background task.
        task.qualityOfService = NSQualityOfService.Background
        
        // Start the process and immediately pause it. The resumeTimer will kick it
        // off when appropriate.
        task.launch()
        pauseMining()
        
        // If we're cool enough to mine, we'll have made a heartbeat
        // already. If not though, we send a data-less heartbeat so
        // we can get the donated amount to display.
        if !coolEnoughToMine { requestManager.sendHeartbeat(false) }
    }
    
    // Update our internal status storing our thermal state, and
    // begin/resume/stop mining as appropriate.
    func thermalStateChanged() {
        let state = NSProcessInfo.processInfo().thermalState
        coolEnoughToMine = (state == NSProcessInfoThermalState.Nominal)
        
        // We have to call this in the main thread so the UI and timer
        // will update correctly.
        dispatch_async(dispatch_get_main_queue(), {
            self.initializeOrInvalidateMinerResumeTimer()
        })
    }
    
    // Initialize the miner resume timer, as long as we're
    // not paused and the thermals are okay.
    func initializeOrInvalidateMinerResumeTimer() {
        let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let statusButton = appDelegate.statusItem.button
        
        // Do nothing if the user's paused or the thermals
        // are too warm.
        if coolEnoughToMine && !userPausedMining {
            // Every 180 seconds, resume the suspended miner process.
            resumeTimer = NSTimer.scheduledTimerWithTimeInterval(
                resumeTimerInterval,
                target: self,
                selector: Selector("resumeMining"),
                userInfo: nil,
                repeats: true
            )
            resumeTimer.tolerance = resumeTimerTolerance // We're not picky about timing.
            
            appDelegate.miningStatus.title = "Status: Running"
            statusButton!.appearsDisabled = false
            requestManager.sendHeartbeat()
        } else {
            // If ther user paused mining, update that takes precedence
            // in the UI. Otherwise, display the computer-too-warm UI.
            if userPausedMining {
                statusButton!.appearsDisabled = true
                appDelegate.miningStatus.title = "Status: Paused"
            } else {
                statusButton!.appearsDisabled = false
                appDelegate.miningStatus.title = "Status: Paused (computer too warm)"
            }
            
            // If we have a valid timer, invalidate it.
            if resumeTimer.valid {
                resumeTimer.invalidate()
                requestManager.sendUnheartbeat()
            }
        }
    }
    
    // Resume the suspended miner process.
    func resumeMining() {
        // Here we resume the miner process and pause it in ten seconds.
        let pauseTimer = NSTimer.scheduledTimerWithTimeInterval(
            miningTimerDuration,
            target: self,
            selector: Selector("pauseMining"),
            userInfo: nil,
            repeats: false
        )
        pauseTimer.tolerance = miningTimerTolerance // We're not picky about timing.

        task.resume() // Let's go!
        requestManager.sendHeartbeat()
        
        dataManager.setHearts(dataManager.getHearts() + heartRate)
    }
    
    // Suspend the miner process.
    func pauseMining() {
        task.suspend()
    }
    
    func setUseMoreCPU(on: Bool) {
        if on {
            miningTimerDuration = miningTimerDurationMoreCpu
            miningTimerTolerance = miningTimerToleranceMoreCpu
            heartRate = heartRateMoreCpu
        } else {
            miningTimerDuration = miningTimerDurationNormal
            miningTimerTolerance = miningTimerToleranceNormal
            heartRate = heartRateNormal
        }
    }
    
    // Kill the miner process. This is used before we kill the
    // parent app.
    func terminateMiner() {
        task.terminate()
        task.waitUntilExit()
    }
}