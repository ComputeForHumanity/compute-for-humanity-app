//
//  AppDelegate.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 5/6/15.
//  Copyright (c) 2015-2016 Jacob Evelyn. All rights reserved.
//

import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var heartsEarned: NSMenuItem!
    @IBOutlet weak var achievementMenuItem: NSMenuItem!
    @IBOutlet weak var donationStatus: NSMenuItem!
    @IBOutlet weak var miningStatus: NSMenuItem!
    @IBOutlet weak var aboutPanel: NSPanel!
    @IBOutlet weak var recruitWindow: NSWindow!
    @IBOutlet weak var recruitURL: AutoHighlightTextField!
    @IBOutlet weak var copiedMessage: NSTextField!
    @IBOutlet weak var moreCpuMenuItem: NSMenuItem!
    @IBOutlet weak var surpriseUUID: AutoHighlightTextField!
    @IBOutlet weak var surpriseClaimWindow: NSWindow!
    
    // These handle separated concerns within the app. Most of them
    // are initialized in the initializer as they depend on each other.
    let notificationManager: NotificationManager = NotificationManager()
    let dataManager: DataManager
    let miningManager: MiningManager
    let requestManager: RequestManager
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    let generalWebsiteURL = NSURL(string: "https://www.computeforhumanity.org")!
    let nAchievementsForSurprise = 10
    let emailAddress = "jacob@computeforhumanity.org"
    
    // We use this private lazy variable to debounce our menu rendering so
    // multiple calls to render the achievements menu in quick succession will be
    // translated into only one operation. The public renderAchievements()
    // method wraps this debouncing behavior transparently.
    lazy private var debouncedRenderAchievements: Debouncer = Debouncer(delay: 0.5) {
        let completedAchievements = self.dataManager.getAchievements()
        var visibleAchievements = Array<String>()
        var nInvisibleAchievements = 0
        
        // Figure out which of the incomplete achievements are visible.
        for (achievement, data) in self.achievements {
            if !completedAchievements.contains(achievement) {
                let prereq = data[1]
                if prereq == "" || completedAchievements.contains(prereq) {
                    visibleAchievements.append(achievement)
                } else {
                    nInvisibleAchievements += 1
                }
            }
        }
        
        // Wipe the entire menu.
        let submenu = self.achievementMenuItem.submenu!
        submenu.removeAllItems()
        
        // Before the achievements menu we want our special surprise item.
        if completedAchievements.count >= self.nAchievementsForSurprise {
            submenu.addItemWithTitle(
                "You've accomplished \(self.nAchievementsForSurprise) 🏆s. Claim your surprise!",
                action: Selector("showSurpriseClaimInstructions"),
                keyEquivalent: ""
            )
        } else {
            submenu.addItemWithTitle(
                "Accomplish \(self.nAchievementsForSurprise) 🏆s for a special surprise!",
                action: Selector("showSurpriseInfoMessage"),
                keyEquivalent: ""
            )
        }
        
        submenu.addItem(NSMenuItem.separatorItem())
        
        // At the top of the menu we want visible, incomplete achievements.
        for achievement in visibleAchievements {
            submenu.addItemWithTitle(self.dataManager.achievementText(achievement), action: nil, keyEquivalent: "")
        }
        
        // Next we want complete achievements.
        for achievement in completedAchievements {
            let item = NSMenuItem.init(title: self.dataManager.achievementText(achievement), action: nil, keyEquivalent: "")
            item.state = 1
            submenu.addItem(item)
        }
        
        // Last of all we want the locked/invisible achievements.
        if nInvisibleAchievements > 0 {
            for _ in 1...nInvisibleAchievements {
                submenu.addItemWithTitle("❔ (Unlock with more 🏆s)", action: nil, keyEquivalent: "")
            }
        }
    }
    
    let achievements = [
        "👽": ["Earn 42 💖s", ""],
        "💻": ["Enable faster 💖 generation", ""],
        "💌": ["Donate 💖s", ""],
        "💕": ["Donate 💖s twice", "💌"],
        "💝": ["Donate 500 💖s at once", "💝"],
        "🏅": ["Donate 10,000 💖s total", "💝"],
        "💑": ["Recruit 1 friend", ""],
        "📬": ["Recruit 3 friends", "💑"],
        "🗣": ["Recruit 10 friends", "📬"],
        "💪": ["Recruit 25 friends", "🗣"],
        "🏋": ["Recruit 75 friends", "💪"],
        "🎖": ["Recruit 200 friends", "🏋"],
        "🌞": ["Donate 💖s at noon", "💻"],
        "🌜": ["Donate 💖s at midnight", "💕"],
        "☄️": ["Donate 💖s on New Year's Day", "💪"],
        "🌹": ["Donate 💖s on Valentine's Day", "👽"],
        "🗓": ["Donate 💖s on February 29th", "🗣"],
        "🍀": ["Donate 💖s on St. Patrick's Day", "📬"],
        "🙃": ["Donate 💖s on April Fools' Day", "🗣"],
        "🌎": ["Donate 💖s on Earth Day", "🎖"],
        "🇺🇸": ["Donate 💖s on July 4th", "💑"],
        "🕊": ["Donate 💖s on International Peace Day", "🎖"],
        "🎃": ["Donate 💖s on Halloween", "📬"],
        "🎄": ["Donate 💖s on Christmas", "💪"],
        "🎊": ["Donate 💖s on New Year's Eve", "🏋"]
    ]
    
    let charities = [
        "💵😍 (GiveDirectly)": "GiveDirectly",
        "🏥😷 (Watsi)": "Watsi",
        "📚🎓 (Pencils of Promise)": "PencilsOfPromise",
        "🌍👨‍👩‍👧‍👦 (GlobalGiving)": "GlobalGiving"
    ]
    
    override init() {
        // Note that we must be careful to ensure that none of these
        // class initializers depend on AppDelegate existing, as they
        // will fire before it does. Things that require AppDelegate
        // should be called externally from appDelegateDidFinishLaunching
        // (see below).
        dataManager = DataManager(notificationManager: notificationManager)
        requestManager = RequestManager(notificationManager: notificationManager, dataManager: dataManager)
        miningManager = MiningManager(dataManager: dataManager, requestManager: requestManager)
        super.init()
    }
    
    // Fired when the application launches.
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // These methods rely on the AppDelegate existing.
        dataManager.initialize()
        miningManager.initialize()
        
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = notificationManager
        
        PFMoveToApplicationsFolderIfNecessary()
        
        BITHockeyManager.sharedHockeyManager().configureWithIdentifier("9550f03563f84e0d9d8d7e51244e4c04")
        // Do some additional configuration if needed here
        BITHockeyManager.sharedHockeyManager().startManager()
        
        initializeIcon()
        addToLoginItems()
        initializeDonationButtons()
        
        renderAchievements()
        setMoreCPUFromValue()
        
        let UUID: String = dataManager.getUUID()
        recruitURL.stringValue = "\(generalWebsiteURL)/?r=\(UUID)"
        surpriseUUID.stringValue = UUID
    }
    
    // Configure the menu items that allow the user to donate hearts
    // to a specific cause, based on the `charities` constant.
    func initializeDonationButtons() {
        let submenu = heartsEarned.submenu!

        // For each charitiy, make a menu item and set its action to
        // call the donate() method below.
        for text in charities.keys {
            let item = NSMenuItem.init(title: text, action: Selector("donate:"), keyEquivalent: "")
            item.target = self
            item.enabled = true
            submenu.addItem(item)
        }
    }
    
    // Called when a heart donation menu item for a given charity is
    // clicked. (`sender` is that menu item.) Donates the user's hearts
    // by:
    // - Transferring their `Hearts` value to `DonatedHearts`.
    // - Sending the donation "vote" HTTP request to the server.
    // - Accomplishing any relevant donation achievements.
    func donate(sender: NSMenuItem) {
        let hearts = dataManager.getHearts()
        
        // Do nothing if we have no hearts to donate.
        if hearts == 0 { return }
        
        let charityId = charities[sender.title]!
        let alreadyDonated = dataManager.getDonatedHearts()
        let totalDonated = alreadyDonated + hearts
        
        dataManager.setHearts(0) // Don't worry about race condition here.
        dataManager.setDonatedHearts(totalDonated)
        
        let emoji = sender.title.substringToIndex(sender.title.startIndex.advancedBy(2))
        let notificationTitle = hearts == 1 ? "You just donated a 💖 to support \(emoji)" : "You just donated \(hearts) 💖s to support \(emoji)"
        let notificationSubtitle = hearts == totalDonated ? "Keep it up!" : "You've donated \(totalDonated) 💖s total!"
        
        notificationManager.sendNotification(notificationTitle, subtitle: notificationSubtitle)
        
        // Do all of the achievement accomplishing.
        dataManager.accomplishDonationAchievements(
            hearts: hearts,
            alreadyDonated: alreadyDonated,
            totalDonated: totalDonated
        )
        
        // Send the HTTP donation request.
        requestManager.donate(charityId, hearts: hearts)
    }
    
    // Re-renders the achievements menu to reflect all of the achievements
    // the user has accomplished.
    func renderAchievements() {
        debouncedRenderAchievements.call()
    }
    
    // Displays a message when the user clicks the special surprise menu item
    // but does not have enough achievements to claim it. The message is shown
    // as an alert.
    func showSurpriseInfoMessage() {
        let alert = NSAlert()
        alert.messageText = "Receive a special surprise in the mail!"
        alert.informativeText = "When you've accomplished \(nAchievementsForSurprise) 🏆s, " +
                            "you'll be able to see instructions for how to receive a special " +
                            "(handmade!) surprise in the mail as a thanks for being an awesome Compute " +
                            "for Humanity user.\n\nSnail mail isn't dead!"
        alert.alertStyle = .InformationalAlertStyle
        alert.runModal()
    }
    
    // Called when the user clicks the special surprise menu item and does have
    // enough achievements to claim one. We display instructions for how to claim
    // the special surprise, and a little more info on what it is.
    func showSurpriseClaimInstructions() {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        surpriseClaimWindow.makeKeyAndOrderFront(self)
    }
    
    // Initialize the status bar icon for this app.
    func initializeIcon() {
        let statusButton = statusItem.button
        let icon = NSImage(named: "statusIcon")
        
        icon?.template = true
        statusButton!.image = icon
        
        statusItem.menu = statusMenu
    }

    // Fired when the app is terminated. Shuts down the miner process.
    func applicationWillTerminate(aNotification: NSNotification) {
        miningManager.terminateMiner()
        requestManager.sendUnheartbeat()
    }

    // Fired when the "About Compute for Humanity" item is selected.
    @IBAction func aboutClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        aboutPanel.makeKeyAndOrderFront(sender)
    }
    
    // Fired when the "Pause" item is checked/unchecked.
    @IBAction func pauseResumeClicked(sender: NSMenuItem) {
        if sender.state == NSOnState {
            miningManager.userPausedMining = false
            sender.state = NSOffState
        } else {
            miningManager.userPausedMining = true
            sender.state = NSOnState
        }
        
        miningManager.initializeOrInvalidateMinerResumeTimer()
    }
    
    // Sets whether we're in more-CPU mode or not from the value
    // in the `values` dictionary. This function both updates
    // relevant variables and sets the menu state.
    func setMoreCPUFromValue() {
        if dataManager.getUseMoreCPU() {
            miningManager.setUseMoreCPU(true)
            moreCpuMenuItem.state = NSOnState
            dataManager.accomplishAchievement("💻")
        } else {
            miningManager.setUseMoreCPU(false)
            moreCpuMenuItem.state = NSOffState
        }
    }
    
    // Fired when the user selects the item to use more CPU
    // power.
    @IBAction func moreCpuClicked(sender: NSMenuItem) {
        // Set our more-CPU mode to "true" if the menu item
        // was not selected previously.
        dataManager.setUseMoreCPU(sender.state == NSOffState)
        
        // This will update the necessary variables as well as
        // the menu item state.
        setMoreCPUFromValue()
    }
    
    // Fired when the "Quit" item is selected.
    @IBAction func quitClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(nil)
    }
    
    // Fired when the website link button within the About panel is selected.
    @IBAction func linkClicked(sender: NSButton) {
        NSWorkspace.sharedWorkspace().openURL(generalWebsiteURL)
    }
    
    // Fired when the user wants to open the recruit window.
    // Opens the window, of course.
    @IBAction func openRecruitPanelClicked(sender: NSMenuItem) {
        copiedMessage.hidden = true // Cheap alternative to fade-out animation.
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        recruitWindow.makeKeyAndOrderFront(sender)
    }
    
    // Fires when the user clicks the button to copy the
    // recruiting link. Saves the link to the clipboard and
    // displays a message.
    @IBAction func recruitLinkClicked(sender: NSButton) {
        let pasteBoard = NSPasteboard.generalPasteboard()
        pasteBoard.clearContents()
        pasteBoard.writeObjects([recruitURL.stringValue])
        copiedMessage.hidden = false
    }
    
    // Fired when the user clicks the Facebook button. Opens a
    // Facebook post window.
    @IBAction func facebookPostClicked(sender: NSButton) {
        let url = NSURL(string: "https://www.facebook.com/sharer/sharer.php?u=https%3A//www.computeforhumanity.org%2F%3Fr%3D" + dataManager.getUUID())
        NSWorkspace.sharedWorkspace().openURL(url!)
    }
    
    // Fired when the user clicks the tweet button. Opens a Twitter
    // tweet intent window.
    @IBAction func tweetClicked(sender: NSButton) {
        let url = NSURL(string: "https://twitter.com/intent/tweet?text=I'm%20earning%20%F0%9F%92%96s%20and%20%F0%9F%8F%86s%20while%20helping%20the%20%F0%9F%8C%8E.%20Let's%20find%20the%20%23SpecialSurprise&url=https%3A%2F%2Fwww.computeforhumanity.org%2F%3Fr%3D" + dataManager.getUUID() + "&hashtags=ComputeForHumanity&via=Jake_Evelyn&related=Give_Directly,watsi,GlobalGiving,PencilsOfPromis")
        NSWorkspace.sharedWorkspace().openURL(url!)
    }
    
    // Adds the app to the system's list of login items.
    // NOTE: This is a relatively janky way of doing this. Using a
    // bundled helper app is Apple's recommended approach, but that
    // has a lot of configuration overhead to get right.
    func addToLoginItems() {
        NSTask.launchedTaskWithLaunchPath(
            "/usr/bin/osascript",
            arguments: [
                "-e",
                "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/Compute for Humanity.app\", hidden:false, name:\"Compute for Humanity\"}"
            ]
        )
    }
}

