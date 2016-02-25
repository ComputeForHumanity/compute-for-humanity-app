//
//  Debouncer.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 2/8/16.
//  Copyright © 2016 Jacob Evelyn. All rights reserved.
//

import Foundation

// This class allows us to debounce method calls. Note that
// the calls are *not* called on the leading edge of the
// debounce.

// Example usage: 
// let debouncedFunction = Debouncer(delay: 0.40) {
//     print("delayed printing")
// }
//
// debouncedFunction.call()
// debouncedFunction.call()

// Modified from code found here: https://github.com/webadnan/swift-debouncer
// (No license listed.)

class Debouncer: NSObject {
    // Apple recommends a tolerance of 10% of the timer duration.
    let tolerancePercentage = 0.1
    
    var callback: (() -> ())
    var delay: Double
    weak var timer: NSTimer?
    
    init(delay: Double, callback: (() -> ())) {
        self.delay = delay
        self.callback = callback
    }
    
    func call() {
        timer?.invalidate()
        let nextTimer = NSTimer.scheduledTimerWithTimeInterval(delay, target: self, selector: "fireNow", userInfo: nil, repeats: false)
        nextTimer.tolerance = delay * tolerancePercentage
        timer = nextTimer
    }
    
    func fireNow() {
        self.callback()
    }
}