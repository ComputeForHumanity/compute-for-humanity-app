//
//  RequestManager.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 2/7/16.
//  Copyright © 2016 Jacob Evelyn. All rights reserved.
//

class RequestManager {
    let notificationManager: NotificationManager
    let dataManager: DataManager
    
    let baseServerURL: String = "https://www.computeforhumanity.org/api/v1"
    
    let unheartbeatURL: NSURL
    
    init(notificationManager: NotificationManager, dataManager: DataManager) {
        self.notificationManager = notificationManager
        self.dataManager = dataManager
        
        let UUID = dataManager.getUUID()
        unheartbeatURL = NSURL(string: baseServerURL + "/unheartbeat?uuid=\(UUID)")!
    }
    
    // Sends a donation HTTP request to the server, for the given charity and number of hearts.
    func donate(charityId: String, hearts: Int) {
        let url: NSURL = NSURL(string: baseServerURL + "/vote?charity=\(charityId)&votes=\(hearts)")!
        NSURLConnection.sendAsynchronousRequest(
            NSURLRequest(URL: url),
            queue: NSOperationQueue(),
            completionHandler: { _,_,_ in }
        )
    }
    
    // Send a heartbeat to the server, for live miner
    // counts and statistics purposes. This indicates that
    // we're mining.
    func sendHeartbeat(sendUUID: Bool = true) {
        var urlPath: String = baseServerURL + "/heartbeat"
        if sendUUID { urlPath += "?uuid=" + "\(dataManager.getUUID())" }
        
        NSURLConnection.sendAsynchronousRequest(
            NSURLRequest(URL: NSURL(string: urlPath)!),
            queue: NSOperationQueue(),
            completionHandler: { (response: NSURLResponse?, data: NSData?, error: NSError?) -> Void in
                let httpResponse = response as? NSHTTPURLResponse
                
                if error == nil && httpResponse != nil && httpResponse?.statusCode == 200 && data != nil {
                    // We need a do..catch to wrap the JSON deserialization `try`.
                    do {
                        let parsedData = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions())
                        
                        let donated = parsedData["donated"] as! String
                        
                        // nRecruits is set to the value sent by the server if present.
                        var nRecruits = 0
                        if (parsedData.valueForKey("nRecruits") != nil) {
                            nRecruits = parsedData["nRecruits"] as! Int
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), {
                            (NSApplication.sharedApplication().delegate as! AppDelegate)
                                .donationStatus.title = "\(donated) donated so far!"
                            
                            if nRecruits > 0 && (nRecruits != self.dataManager.getNRecruits()) {
                                self.dataManager.setNRecruits(nRecruits)
                                
                                self.notificationManager.sendNotification(
                                    "One of your friends just joined!",
                                    subtitle: "Thanks for sharing Compute for Humanity! 😊"
                                )
                                
                                // We don't use else-ifs here because in one update we
                                // might feasibly accomplish more than one achievement
                                // at once.
                                if nRecruits >= 1 { self.dataManager.accomplishAchievement("💑") }
                                if nRecruits >= 3 { self.dataManager.accomplishAchievement("📬") }
                                if nRecruits >= 10 { self.dataManager.accomplishAchievement("🗣") }
                                if nRecruits >= 25 { self.dataManager.accomplishAchievement("💪") }
                                if nRecruits >= 75 { self.dataManager.accomplishAchievement("🏋") }
                                if nRecruits >= 200 { self.dataManager.accomplishAchievement("🎖") }
                            }
                        })
                    } catch {}
                }
            }
        )
    }
    
    // Send an un-heartbeat to the server, for live miner
    // counts and statistics purposes. It indicates that we're
    // no longer mining.
    func sendUnheartbeat() {
        NSURLConnection.sendAsynchronousRequest(
            NSURLRequest(URL: unheartbeatURL),
            queue: NSOperationQueue(),
            completionHandler: { _,_,_ in }
        )
    }
}