//
//  Logger.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import AlertKit

public struct Logger {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Other Declarations
    public static var exposureLevel: ExposureLevel = .normal
    
    private static var streamOpen = false
    
    //==================================================//
    
    /* MARK: - Enumerated Type Declarations */
    
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
           verbose && exposureLevel != .verbose {
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
        
        print("\n--------------------------------------------------\n\(fileName): \(functionName)() [\(lineNumber)]\n\(text)\n--------------------------------------------------\n")
        
        guard let alertType = with else {
            return
        }
        
        switch alertType {
        case .errorAlert:
            let akError = AKError(text,
                                  metadata: [fileName, functionName, lineNumber],
                                  isReportable: true)
            AKErrorAlert(error: akError).present()
        case .fatalAlert:
            AKCore.shared.present(.fatalErrorAlert,
                                  with: [text,
                                         buildType != .generalRelease,
                                         [fileName, functionName, lineNumber]])
        case .normalAlert:
            AKAlert(message: text,
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
            
            guard let firstEntry = message else {
                print("\n*------------------------STREAM OPENED------------------------*\n\(fileName): \(functionName)()")
                return
            }
            
            print("\n*------------------------STREAM OPENED------------------------*\n\(fileName): \(functionName)()\n[\(lineNumber)]: \(firstEntry)")
        }
    }
    
    public static func logToStream(_ message: String,
                                   line: Int) {
        if exposureLevel == .verbose {
            print("[\(line)]: \(message)")
        }
    }
    
    public static func closeStream(message: String? = nil,
                                   onLine: Int? = nil) {
        if exposureLevel == .verbose {
            streamOpen = false
            
            guard let closingMessage = message,
                  let line = onLine else {
                print("*------------------------STREAM CLOSED------------------------*\n")
                return
            }
            
            print("[\(line)]: \(closingMessage)\n*------------------------STREAM CLOSED------------------------*\n")
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
    
    private static func fallbackLog(_ text: String,
                                    with: AlertType? = nil) {
        print("\n--------------------------------------------------\n[IMPROPERLY FORMATTED METADATA]\n\(text)\n--------------------------------------------------\n")
        
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
                                         buildType != .generalRelease,
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
              metadata[2] is Int else {
            return false
        }
        
        return true
    }
}
