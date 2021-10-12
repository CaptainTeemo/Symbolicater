//
//  DragAndDropTextField.swift
//  Symbolicater
//
//  Created by Keven on 10/11/21.
//  
//
	

import Foundation
import AppKit

class DragAndDropTextField: NSTextField {
    
    var dragIsOver = false
    
    var targetType = NSPasteboard.PasteboardType("NSFilenamesPboardType") {
        didSet {
            self.unregisterDraggedTypes()
            self.registerForDraggedTypes([targetType])
        }
    }
    
    override func awakeFromNib() {
        self.registerForDraggedTypes([targetType])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        
        super.draw(dirtyRect)
        
        if dragIsOver {
            NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.25).set()
            NSInsetRect(bounds, 1, 1).fill()
        }
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.types?.contains(targetType) == true {
            dragIsOver = true
            needsDisplay = true
            return .copy
        }
        return .generic
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragIsOver = false
        needsDisplay = true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.types?.contains(targetType) == true {
            let files = pasteboard.propertyList(forType: targetType) as? [String]
            if let url = files?.first {
                self.stringValue = url
                dragIsOver = false
                needsDisplay = true
            }
            
        }
        
        return true
    }
}
