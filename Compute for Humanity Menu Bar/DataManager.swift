//
//  DataManager.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 2/7/16.
//  Copyright © 2016 Jacob Evelyn. All rights reserved.
//

class DataManager {
    var notificationManager: NotificationManager
    
    let UUIDKey = "UUID"
    let heartsKey = "Hearts"
    let donatedHeartsKey = "DonatedHearts"
    let achievementsKey = "Achievements"
    let nRecruitsKey = "NRecruits"
    let moreCPUKey = "UseMoreCPU"
    
    // If this value is changed, we must update it in the .xib as well.
    let heartsPerRecruit = 999
    
    let fileManager = NSFileManager.defaultManager()
    let dataFileURL: NSURL
    
    // We use this private lazy variable to debounce our file writing so
    // multiple calls to write the file in quick succession will be
    // translated into only one write.
    lazy private var debouncedWriteToFile: Debouncer = Debouncer(delay: 1) {
        (self.values as NSDictionary).writeToURL(self.dataFileURL, atomically: true)
    }
    
    var values = [String:AnyObject]()
    
    // Read in our settings file and set initial values from it,
    // falling back to hardcoded defaults.
    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        
        dataFileURL = try! fileManager.URLForDirectory(
            .ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true
            ).URLByAppendingPathComponent("ComputeForHumanity", isDirectory: true)
            .URLByAppendingPathComponent("ComputeForHumanityData.plist")
        
        // If the data file exists, read it.
        if fileManager.fileExistsAtPath(dataFileURL.path!) {
            for (key, val) in NSDictionary(contentsOfURL: dataFileURL)! {
                values[key as! String] = val
            }
        } else {
            let directoryURL = dataFileURL.URLByDeletingLastPathComponent!
            
            // If the directory doesn't already exist, create it.
            if !fileManager.fileExistsAtPath(directoryURL.path!) {
                try! fileManager.createDirectoryAtURL(
                    directoryURL,
                    withIntermediateDirectories: true,
                    attributes: [:]
                )
            }
        }
        
        // We modify the values dictionary directly here rather than calling
        // setters, because that can have side effects that don't work when
        // the app is not fully initialized (for instance, accessing the
        // AppDelegate in setHearts() will fail).
        if values[UUIDKey] == nil { values[UUIDKey] = NSUUID().UUIDString }
        if values[heartsKey] == nil { values[heartsKey] = 0 }
        if values[donatedHeartsKey] == nil { values[donatedHeartsKey] = 0 }
        if values[nRecruitsKey] == nil { values[nRecruitsKey] = 0 }
        if values[achievementsKey] == nil { values[achievementsKey] = [] }
        if values[moreCPUKey] == nil { values[moreCPUKey] = false }
    }
    
    // Run any methods whose side effects we rely on, now that the app is
    // initialized.
    func initialize() {
        debouncedWriteToFile.call()
        setHearts(getHearts())
        setAchievementsCountMessage()
    }
    
    // Sets the menu item message for the number of achievements accomplished.
    func setAchievementsCountMessage() {
        let delegate = appDelegate()
        let nTotalAchievements = delegate.achievements.count
        let nAchievements = getAchievements().count
        delegate.achievementMenuItem.title = "Your 🏆s accomplished: \(nAchievements)/\(nTotalAchievements)"
    }
    
    // Returns the text to display for an achievement, given the
    // single emoji that represents it.
    func achievementText(name: String) -> String {
        return "\(name) (\(appDelegate().achievements[name]![0]))"
    }
    
    // Accomplish the achievement represented by the emoji passed in, and
    // optionally writes out the new data to the configuration file. Triggers
    // a re-rendering of the achievements menu and a notification.
    func accomplishAchievement(achievement: String) {
        var achievementsArr = getAchievements()
        
        // If the achievement has already been accomplished, short-circuit.
        if achievementsArr.contains(achievement) { return }
        
        achievementsArr.append(achievement)
        values.updateValue(achievementsArr, forKey: "Achievements")
        
        appDelegate().renderAchievements()
        
        notificationManager.sendNotification(
            "🏆 accomplished!",
            subtitle: achievementText(achievement)
        )
        
        setAchievementsCountMessage()
        debouncedWriteToFile.call()
    }
    
    // Accomplish any relevant donation achievements.
    func accomplishDonationAchievements(hearts hearts: Int, alreadyDonated: Int, totalDonated: Int) {
        let now =  NSDate()
        let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        let month = calendar.component(.Month, fromDate: now)
        let day = calendar.component(.Day, fromDate: now)
        let time = calendar.ordinalityOfUnit(.Minute, inUnit: .Day, forDate: now)
        
        accomplishAchievement("💌")
        if alreadyDonated > 0 { accomplishAchievement("💕") }
        if hearts >= 500 { accomplishAchievement("💝") }
        if totalDonated >= 10000 { accomplishAchievement("🏅") }
        if time == 1 { accomplishAchievement("🌜") }
        if time == 721 { accomplishAchievement("🌞") }
        
        if month == 1 && day == 1 { accomplishAchievement("☄️") }
        else if month == 2 && day == 14 { accomplishAchievement("🌹") }
        else if month == 2 && day == 29 { accomplishAchievement("🗓") }
        else if month == 3 && day == 17 { accomplishAchievement("🍀") }
        else if month == 4 && day == 1 { accomplishAchievement("🙃") }
        else if month == 4 && day == 22 { accomplishAchievement("🌎") }
        else if month == 7 && day == 4 { accomplishAchievement("🇺🇸") }
        else if month == 9 && day == 21 { accomplishAchievement("🕊") }
        else if month == 10 && day == 31 { accomplishAchievement("🎃") }
        else if month == 12 && day == 25 { accomplishAchievement("🎄") }
        else if month == 12 && day == 31 { accomplishAchievement("🎊") }
    }
    
    func getUUID() -> String { return values[UUIDKey] as! String }
    func getHearts() -> Int { return values[heartsKey] as! Int }
    func setHearts(val: Int) {
        if val >= 42 { accomplishAchievement("👽") }
        
        appDelegate().heartsEarned.title = "Your 💖s earned: \(val) (\(getDonatedHearts()) donated)"
        
        values[heartsKey] = val
        debouncedWriteToFile.call()
    }
    func getDonatedHearts() -> Int { return values[donatedHeartsKey] as! Int }
    func setDonatedHearts(val: Int) {
        appDelegate().heartsEarned.title = "Your 💖s earned: \(getHearts()) (\(val) donated)"
        
        values[donatedHeartsKey] = val
        debouncedWriteToFile.call()
    }
    func getNRecruits() -> Int { return values[nRecruitsKey] as! Int }
    func setNRecruits(val: Int) {
        let oldVal = getNRecruits()
        values[nRecruitsKey] = val
        
        // Add hearts if we recruited new users.
        setHearts(getHearts() + (val - oldVal) * heartsPerRecruit)
        
        debouncedWriteToFile.call()
    }
    func getUseMoreCPU() -> Bool { return values[moreCPUKey] as! Bool }
    func setUseMoreCPU(val: Bool) {
        values[moreCPUKey] = val
        debouncedWriteToFile.call()
    }
    func getAchievements() -> Array<String> { return values[achievementsKey] as! Array<String> }
    
    private func appDelegate() -> AppDelegate {
        return NSApplication.sharedApplication().delegate as! AppDelegate
    }
}