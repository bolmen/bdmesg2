//
//  ViewController.swift
//  bdmesg2
//
//  Created by Tim Richter on 2019-02-14.
//  Copyright © 2019 Tim Richter. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var leftScrollView: NSScrollView!
    @IBOutlet weak var rightScrollView: NSScrollView!
    @IBOutlet weak var leftClipView: NSClipView!
    @IBOutlet weak var rightClipView: NSClipView!
    @IBOutlet var leftTextView: NSTextView!
    @IBOutlet var rightTextView: NSTextView!
    @IBOutlet weak var rightScroller: NSScroller!
    @IBOutlet weak var syncButton: NSButtonCell!
    @IBOutlet weak var compareButtonCell: NSPopUpButtonCell!
    @IBOutlet weak var statusTextViewCell: NSTextFieldCell!

    // We need UserDefaults a couple of times later

    let defaults = UserDefaults()
    
    @IBAction func syncButtonAction(_ sender: NSButtonCell) {
        
        if (syncButton.state.rawValue == 1) {
            
            leftClipView.postsBoundsChangedNotifications = true
            rightScroller.isHidden = true
            leftClipView.postsBoundsChangedNotifications = true
            
        } else {
            
            leftClipView.postsBoundsChangedNotifications = false
            rightScroller.isHidden = false
            leftClipView.postsBoundsChangedNotifications = false
            
        }
        
        defaults.set(syncButton.state.rawValue, forKey: "syncScrolling")
        
    }

    
    @IBAction func compareButtonCellAction(_ sender: NSPopUpButtonCell) {
        
        // Set the split view for one or two log files
        
        let spWidth = splitView.bounds.width
       
        if (compareButtonCell.indexOfSelectedItem == 0) {
            
            splitView.setPosition(spWidth, ofDividerAt: 0)
            syncButton.isEnabled = false
            rightTextView.string = "Nothing here yet"
            splitView.setValue(NSColor.controlBackgroundColor, forKey: "dividerColor")
            
        } else {
            
            if (rightClipView.bounds.width == 0.0) {
                splitView.setPosition(spWidth / 2 - 1, ofDividerAt: 0)
            }
            
            syncButton.isEnabled = true
            
            let savedLogs = defaults.dictionary(forKey: "savedLogs") as! [String : Data]
            let logText = String(data: savedLogs[compareButtonCell.titleOfSelectedItem!] ?? Data(), encoding: .utf8) ?? "Error: couldn't load boot-log from UserDefaults"
            
            rightTextView.string = logText
            
            splitView.setValue(NSColor.gridColor, forKey: "dividerColor")
            
        }
        
        defaults.set(compareButtonCell.indexOfSelectedItem, forKey: "compareItem")
        
    }

    
    @objc func clipViewDidScroll(_ notification: Notification) {
        
        // Synchronise vertical scrolling of both TextViews
        
        rightClipView.scroll(to: NSPoint(x: rightClipView.bounds.minX, y: leftClipView.bounds.minY))
        
        
        // Hide the right scrollbar
        
        rightScroller.isHidden = true
  
        
        // Avoid "unpainted" areas
        
        rightClipView.drawsBackground = true
    }
    
    
    @objc func leftFontDidChange(_ notification: Notification) {
        
        // Save chosen font/size to defaults and sync left/right textView font

        if (syncButton.state.rawValue == 1) {
            rightTextView.font = leftTextView.font
        }
        
        defaults.set(leftTextView.font?.pointSize, forKey: "fontSize")
        defaults.set(leftTextView.font?.fontName, forKey: "fontName")

    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Enable horizontal scrolling
        
        leftScrollView.hasHorizontalScroller = true
        leftTextView.maxSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
        leftTextView.isHorizontallyResizable = true
        leftTextView.textContainer?.widthTracksTextView = false
        leftTextView.textContainer?.containerSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
        
        rightScrollView.hasHorizontalScroller = true
        rightTextView.maxSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
        rightTextView.isHorizontallyResizable = true
        rightTextView.textContainer?.widthTracksTextView = false
        rightTextView.textContainer?.containerSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
        
        
        // Prepare everything for synced scrolling
        
        leftClipView.postsBoundsChangedNotifications = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(clipViewDidScroll(_ :)), name: NSView.boundsDidChangeNotification, object: leftClipView)
        
        
        // We need to react on font/size changes
        
        NotificationCenter.default.addObserver(self, selector: #selector(leftFontDidChange(_ :)), name: NSTextView.didChangeTypingAttributesNotification, object: leftTextView)
        
        
        // Restore saved font setings
        
        var font: NSFont?
        let fontSize = defaults.float(forKey: "fontSize")
        let fontName = defaults.string(forKey: "fontName")
        
        if let name = fontName {
            font = NSFont(name: name, size: CGFloat(fontSize))
        }
        else {
            font = NSFont(name: "Courier", size: 14.0)!
        }
        
        leftTextView.font = font
        rightTextView.font = font
        
        
        // Restore saved scrolling setting
        
        if (defaults.integer(forKey: "syncScrolling") == 1) {
            syncButton.performClick(self)
        }
        
        
        // Load the current boot-log
        
        let currentLog = getCurrentLog()
        let logText = String(data: currentLog, encoding: .utf8)!
        let logDateRegex = logText.matchingStrings(regex: "Now is (.+)")
        let cloverRevisionRegex = logText.matchingStrings(regex: "Clover rev[ision:]* (\\w+) on")
        let formatter = DateFormatter()
        
        formatter.dateFormat = "dd.MM.yyyy, HH:mm:ss (zzz)"
        formatter.timeZone = TimeZone(identifier: "GMT")
        
        
        // Retrieve and format the log date from current boot-log
        
        var logDate = String("unknown date")
        
        if (logDateRegex.count == 1) {
            let rawLogDate = logDateRegex.last!.last!
            
            // Format the logDate
        
            if let date = formatter.date(from: rawLogDate) {
                logDate = formatter.string(from: date)
            }
        }

        
        // Retrieve Clover version from current boot-log
        
        var cloverRevision = String("unknown")

        if (cloverRevisionRegex.count == 1) {
            cloverRevision = cloverRevisionRegex.last!.last!
        }

        statusTextViewCell.stringValue = "Boot-log from " + logDate + " found on IODeviceTree:/efi/platform, Clover revision: r" + cloverRevision
        leftTextView.string = logText
        
        
        // Save/retrieve logs in UserDefaults
        
        var savedLogs = Dictionary<String, Data>()
        let key = logDate + ", r" + cloverRevision
        
        if (defaults.dictionary(forKey: "savedLogs") == nil) {
            savedLogs.updateValue(currentLog, forKey: key)
            //debugPrint("No saved boot-logs found in UserDefaults, adding entry for " + key)
        } else {
            savedLogs = defaults.dictionary(forKey: "savedLogs") as! [String : Data]
           
            if (!Array(savedLogs.keys).contains(key)) {
                savedLogs.updateValue(currentLog, forKey: key)
                //debugPrint("Found saved boot-logs, adding entry for " + key)
            }
        }
        
        defaults.setValue(savedLogs, forKey: "savedLogs")
        
        compareButtonCell.addItems(withTitles: Array(savedLogs.keys).sorted().reversed())
        compareButtonCell.autoenablesItems = false
        compareButtonCell.item(withTitle: key)?.isEnabled = false
    
        
        // Restore the "Compare with..." popup
        
        compareButtonCell.selectItem(at: defaults.integer(forKey: "compareItem"))
        compareButtonCell.performClick(self)
        
    }
    
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
    func getCurrentLog() -> Data {
        let log = "boot-log" as CFString
        let root = IORegistryEntryFromPath(kIOMasterPortDefault, "IODeviceTree:/efi/platform")
        
        var bootLogRef: Unmanaged<CFTypeRef>!
        var bootLogData = "No boot-log found on IODeviceTree:/efi/platform".data(using: .utf8)! as CFData
        
        if (root != MACH_PORT_NULL)
        {
            bootLogRef = IORegistryEntryCreateCFProperty(root, log, kCFAllocatorDefault, 0)
        }

        if (bootLogRef != nil) {
            bootLogData = Unmanaged.fromOpaque(bootLogRef.toOpaque()).takeUnretainedValue() as CFData
        }
        
        return bootLogData as Data
    }
}


extension String {

    // Friendly regex helper

    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}
