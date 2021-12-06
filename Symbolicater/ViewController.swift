//
//  ViewController.swift
//  Symbolicater
//
//  Created by Keven on 10/11/21.
//  
//
	

import Cocoa
import UniformTypeIdentifiers

private let dSYMKey = "dSYMPath"
private let logKey = "logPath"
private let bundleIdKey = "bundleId"

class ViewController: NSViewController {
    @IBOutlet weak var dsymTextField: DragAndDropTextField!
    @IBOutlet weak var dsymButton: NSButton!
    @IBOutlet weak var logTextField: DragAndDropTextField!
    @IBOutlet weak var logButton: NSButton!
    @IBOutlet weak var bundleIdTextField: NSTextField!
    @IBOutlet var logView: NSTextView!
    @IBOutlet weak var symbolicateButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if let dSYMPath = UserDefaults.standard.string(forKey: dSYMKey) {
            dsymTextField.stringValue = dSYMPath
        }
        
        if let logPath = UserDefaults.standard.string(forKey: logKey) {
            logTextField.stringValue = logPath
        }
        
        if let bundleId = UserDefaults.standard.string(forKey: bundleIdKey) {
            bundleIdTextField.stringValue = bundleId
        }
        
        dsymTextField.onStringSet = { path in
            UserDefaults.standard.set(path, forKey: dSYMKey)
            UserDefaults.standard.synchronize()
        }
        
        logTextField.onStringSet = { path in
            UserDefaults.standard.set(path, forKey: logKey)
            UserDefaults.standard.synchronize()
        }
        
        logView.font = NSFont(name: "SF Pro", size: 12)
        logView.maxSize = NSSize(width: Double.greatestFiniteMagnitude, height: Double.greatestFiniteMagnitude)
        logView.isHorizontallyResizable = true
        logView.textContainer?.widthTracksTextView = false
        logView.textContainer?.containerSize = NSSize(width: Double.greatestFiniteMagnitude, height: Double.greatestFiniteMagnitude)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func didPressDSYMSelect(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        panel.allowedContentTypes = [UTType(tag: "dSYM", tagClass: .filenameExtension, conformingTo: nil)!]
        
        if let window = self.view.window {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let path = panel.url?.path {
                    self.dsymTextField.stringValue = path
                }
            }
        }
    }
    
    @IBAction func didPressLogSelect(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        panel.allowedContentTypes = [.log, .text]
        
        if let window = self.view.window {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let path = panel.url?.path {
                    self.logTextField.stringValue = path
                }
            }
        }
    }
    
    @IBAction func didPressSymbolicate(_ sender: NSButton) {
        self.logView.string = ""
        
        let dSYMPath = dsymTextField.stringValue
        let logPath = logTextField.stringValue

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        
        let dSYMURL = URL(fileURLWithPath: dSYMPath)
        let executableFolder = dSYMURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("DWARF")
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
                
        let outputHandler = outputPipe.fileHandleForReading
        outputHandler.waitForDataInBackgroundAndNotify()
        
        outputHandler.readabilityHandler = { handle in
            if let data = try? handle.readToEnd(),
               let content = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.symbolicateButton.title = "Symbolicate"
                    self.logView.string = content
                }
            }
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: executableFolder.path)
            guard let file = files.first else {
                return
            }
            
            let executableFile = executableFolder.appendingPathComponent(file)
            guard let scriptPath = Bundle.main.path(forResource: "symbolicate", ofType: "py") else {
                return
            }
            
            var arguments = [scriptPath, executableFile.path, logPath]
            
            let bundleId = bundleIdTextField.stringValue
            if !bundleId.isEmpty {
                arguments.append(bundleId)
                UserDefaults.standard.set(bundleId, forKey: bundleIdKey)
                UserDefaults.standard.synchronize()
            }
            process.arguments = arguments
            
            symbolicateButton.title = "Symbolicating..."
            process.launch()
            process.waitUntilExit()
            process.terminate()
        } catch {
            print(error)
            self.symbolicateButton.title = "Symbolicate"
        }
    }
    
}
