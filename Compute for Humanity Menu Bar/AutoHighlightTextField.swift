//
//  AutoHighlightTextField.swift
//  Compute for Humanity
//
//  Created by Jacob Evelyn on 2/5/16.
//  Copyright © 2016 Jacob Evelyn. All rights reserved.
//

class AutoHighlightTextField: NSTextField {
    override func mouseDown(theEvent: NSEvent) {
        super.mouseDown(theEvent)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
    
    // This is necessary to enable copying of the text field via
    // the keyboard CMD+C shortcut.
    override func performKeyEquivalent(event: NSEvent) -> Bool {
        if event.type == NSEventType.KeyDown {
            if event.charactersIgnoringModifiers! == "c" &&
                event.modifierFlags.rawValue &
                NSEventModifierFlags.DeviceIndependentModifierFlagsMask.rawValue &
                NSEventModifierFlags.CommandKeyMask.rawValue ==
                NSEventModifierFlags.CommandKeyMask.rawValue {
                if NSApp.sendAction(Selector("copy:"), to:nil, from:self) { return true }
            }
        }
        return super.performKeyEquivalent(event)
    }
}