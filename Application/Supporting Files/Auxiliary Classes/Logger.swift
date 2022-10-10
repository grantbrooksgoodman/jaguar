//
//  Logger.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import AlertKit

public enum Logger {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static var exposureLevel: ExposureLevel = .normal
    
    private static var currentTimeLastCalled = Date()
    private static var streamOpen = false
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum AlertType {
        case errorAlert
        case fatalAlert
        
        case normalAlert
    }
    
    public enum ExposureLevel {
        case verbose
        case normal
    }
    
    //==================================================//
    
    /* MARK: - Logging Functions */
    
    public static func log(_ error: Error,
                           with: AlertType? = nil,
                           verbose: Bool? = nil,
                           metadata: [Any]) {
        log(errorInfo(error),
            with: with,
            verbose: verbose,
            metadata: metadata)
    }
    
    public static func log(_ error: NSError,
                           with: AlertType? = nil,
                           verbose: Bool? = nil,
                           metadata: [Any]) {
        log(errorInfo(error),
            with: with,
            verbose: verbose,
            metadata: metadata)
    }
    
    public static func log(_ text: String,
                           with: AlertType? = nil,
                           verbose: Bool? = nil,
                           metadata: [Any]) {
        if let verbose = verbose,
           verbose, exposureLevel != .verbose {
            return
        }
        
        guard validateMetadata(metadata) else {
            fallbackLog(text, with: with)
            return
        }
        
        let fileName = AKCore.shared.fileName(for: metadata[0] as! String)
        let functionName = (metadata[1] as! String).components(separatedBy: "(")[0]
        let lineNumber = metadata[2] as! Int
        
        guard !streamOpen else {
            logToStream(text, line: lineNumber)
            return
        }
        
        print("\n--------------------------------------------------\n\(fileName): \(functionName)() [\(lineNumber)]\(elapsedTime())\n\(text)\n--------------------------------------------------\n")
        
        currentTimeLastCalled = Date()
        
        guard let alertType = with else {
            return
        }
        
        switch alertType {
        case .errorAlert:
            let akError = AKError(text.simpleErrorDescriptor(),
                                  metadata: [fileName, functionName, lineNumber],
                                  isReportable: true)
            AKErrorAlert(error: akError).present()
        case .fatalAlert:
            AKCore.shared.present(.fatalErrorAlert,
                                  with: [text,
                                         Build.stage != .generalRelease,
                                         [fileName, functionName, lineNumber]])
        case .normalAlert:
            AKAlert(message: text.simpleErrorDescriptor(),
                    cancelButtonTitle: "OK").present()
        }
    }
    
    //==================================================//
    
    /* MARK: - Stream Functions */
    
    public static func openStream(message: String? = nil,
                                  metadata: [Any]) {
        if exposureLevel == .verbose {
            guard validateMetadata(metadata) else {
                Logger.log("Improperly formatted metadata.",
                           metadata: [#file, #function, #line])
                return
            }
            
            let fileName = AKCore.shared.fileName(for: metadata[0] as! String)
            let functionName = (metadata[1] as! String).components(separatedBy: "(")[0]
            let lineNumber = metadata[2] as! Int
            
            streamOpen = true
            
            currentTimeLastCalled = Date()
            
            guard let firstEntry = message else {
                print("\n*------------------------STREAM OPENED------------------------*\n\(fileName): \(functionName)()\(elapsedTime())")
                return
            }
            
            print("\n*------------------------STREAM OPENED------------------------*\n\(fileName): \(functionName)()\n[\(lineNumber)]: \(firstEntry)\(elapsedTime())")
        }
    }
    
    public static func logToStream(_ message: String,
                                   line: Int) {
        if exposureLevel == .verbose {
            print("[\(line)]: \(message)\(elapsedTime())")
        }
    }
    
    public static func closeStream(message: String? = nil,
                                   onLine: Int? = nil) {
        if exposureLevel == .verbose {
            streamOpen = false
            
            currentTimeLastCalled = Date()
            
            guard let closingMessage = message,
                  let line = onLine else {
                print("*------------------------STREAM CLOSED------------------------*\n")
                return
            }
            
            print("[\(line)]: \(closingMessage)\(elapsedTime())\n*------------------------STREAM CLOSED------------------------*\n")
        }
    }
    
    //==================================================//
    
    /* MARK: - Error Processing Functions */
    
    /**
     Converts an instance of `Error` to a formatted string.
     
     - Parameter for: The `Error` whose information will be extracted.
     
     - Returns: A string with the error's localized description and code.
     */
    public static func errorInfo(_ for: Error) -> String {
        let asNSError = `for` as NSError
        
        return "\(asNSError.localizedDescription) (\(asNSError.code))"
    }
    
    /**
     Converts an instance of `NSError` to a formatted string.
     
     - Parameter for: The `NSError` whose information will be extracted.
     
     - Returns: A string with the error's localized description and code.
     */
    public static func errorInfo(_ for: NSError) -> String {
        return "\(`for`.localizedDescription) (\(`for`.code))"
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private static func currentTime() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        return timeFormatter.string(from: Date())
    }
    
    private static func elapsedTime() -> String {
        let time = String(abs(currentTimeLastCalled.amountOfSeconds(from: Date())))
        
        return time == "0" ? "" : " @ \(time)s FLC"
    }
    
    private static func fallbackLog(_ text: String,
                                    with: AlertType? = nil) {
        print("\n--------------------------------------------------\n[IMPROPERLY FORMATTED METADATA]\n\(text)\n--------------------------------------------------\n")
        
        currentTimeLastCalled = Date()
        
        guard let alertType = with else {
            return
        }
        
        switch alertType {
        case .errorAlert:
            let akError = AKError(text,
                                  metadata: [#file, #function, #line],
                                  isReportable: true)
            AKErrorAlert(error: akError).present()
        case .fatalAlert:
            AKCore.shared.present(.fatalErrorAlert,
                                  with: [text,
                                         Build.stage != .generalRelease,
                                         [#file, #function, #line]])
        case .normalAlert:
            AKAlert(message: text,
                    cancelButtonTitle: "OK").present()
        }
    }
    
    private static func validateMetadata(_ metadata: [Any]) -> Bool {
        guard metadata.count == 3,
              metadata[0] is String,
              metadata[1] is String,
              metadata[2] is Int
        else {
            return false
        }
        
        return true
    }
}
