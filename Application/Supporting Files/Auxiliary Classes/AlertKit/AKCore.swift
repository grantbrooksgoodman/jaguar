//
//  AKCore.swift
//  AlertKit
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/**
 The core functions of **AlertKit**.
 */
public final class AKCore {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public static let shared = AKCore()
    
    //==================================================//
    
    /* MARK: - Presentation Functions */
    
    public func present(_ type: AKCoreAlertType, with: Any? = nil) {
        switch type {
        case .connectionAlert:
            presentConnectionAlert()
        case .expiryAlert:
            buildInfoController?.presentExpiryAlert()
        case .feedbackAlert:
            guard with != nil,
                  let metadata = with as? [Any] else {
                fatalError("Improperly formatted additional metadata.")
            }
            
            fileReport(type: .feedback,
                       body: "Appended below are various data points useful in analysing any potential problems within the application. Please do not edit the information contained in the lines below, with the exception of the last field, in which any general feedback is appreciated.",
                       prompt: "General Feedback",
                       extraInfo: nil,
                       metadata: metadata)
        case .fatalErrorAlert:
            guard with != nil,
                  let data = with as? [Any],
                  data.count == 2,
                  data[0] is String,
                  data[1] is [Any] else {
                
                guard with != nil,
                      with is [Any] else {
                    fatalError("Improperly formatted additional metadata.")
                }
                
                presentFatalErrorAlert(description: nil,
                                       metadata: with as! [Any])
                return
            }
            
            presentFatalErrorAlert(description: (data[0] as! String),
                                   metadata: data[1] as! [Any])
        }
    }
    
    private func presentConnectionAlert() {
        let alertController = UIAlertController(title: Localizer.preLocalizedString(for: .noInternetTitle) ?? "Internet Connection Offline",
                                                message: Localizer.preLocalizedString(for: .noInternetMessage) ?? "The internet connection appears to be offline.\n\nPlease connect to the internet and try again.",
                                                preferredStyle: .alert)
        
        let dismissAction = UIAlertAction(title: Localizer.preLocalizedString(for: .dismiss) ?? "OK",
                                          style: .cancel)
        
        alertController.addAction(dismissAction)
        alertController.preferredAction = dismissAction
        
        politelyPresent(viewController: alertController)
    }
    
    private func presentFatalErrorAlert(description: String?, metadata: [Any]) {
        let continueExecutionInput = TranslationInput("Continue Execution")
        let exitApplicationInput = TranslationInput("Exit Application")
        let fatalExceptionInput = TranslationInput("Fatal Exception")
        let undocumentedErrorInput = TranslationInput("Unfortunately, a fatal error has occurred. It is not possible to continue working normally – exit the application to prevent further error or possible data corruption.\n\nAn error descriptor has been copied to the clipboard.")
        
        TranslatorService.main.getTranslations(for: [undocumentedErrorInput,
                                                     fatalExceptionInput,
                                                     exitApplicationInput,
                                                     continueExecutionInput],
                                               languagePair: LanguagePair(from: "en",
                                                                          to: languageCode),
                                               requiresHUD: true,
                                               using: .google) { (returnedTranslations,
                                                                  errorDescriptors) in
            guard let translations = returnedTranslations else {
                Logger.log(errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            guard let code = AKCore.shared.code(for: .error, metadata: metadata) else {
                fatalError("Unable to generate code.")
            }
            
            var message = translations.first(where: { $0.input.value() == undocumentedErrorInput.value() })?.output ?? undocumentedErrorInput.value()
            
            if let description = description {
                message.append(self.fatalErrorDescriptor(description))
            }
            
            let alertController = UIAlertController(title: translations.first(where: { $0.input.value() == fatalExceptionInput.value() })?.output ?? fatalExceptionInput.value(),
                                                    message: message,
                                                    preferredStyle: .alert)
            
            let exitAction = UIAlertAction(title: translations.first(where: { $0.input.value() == exitApplicationInput.value() })?.output ?? exitApplicationInput.value(),
                                           style: .cancel) { _ in
                UIPasteboard.general.string = "[\(code)]"
                fatalError()
            }
                                                
                                                let continueExecutionAction = UIAlertAction(title: translations.first(where: { $0.input.value() == continueExecutionInput.value() })?.output ?? continueExecutionInput.value(),
                                                                                            style: .destructive) { _ in
                                                    UIPasteboard.general.string = "[\(code)]"
                                                }
                                                
                                                alertController.addAction(exitAction)
            
            if buildType != .generalRelease {
                alertController.addAction(continueExecutionAction)
            }
            
            politelyPresent(viewController: alertController)
        }
    }
    
    //==================================================//
    
    /* MARK: - Helper Functions */
    
    /**
     Generates a coded string for the specified `ReportType`.
     
     - Parameter type: The `ReportType` of the code to generate.
     - Parameter metadata: The metadata array. Must contain the **file name, function name, and line number** in that order.
     
     - Requires: A well-formed *metadata* array.
     - Returns: Upon success, a string representing the generated code. Upon failure, returns `nil`.
     */
    private func code(for type: ReportType, metadata: [Any]) -> String? {
        guard validateMetadata(metadata) else {
            Logger.log("Improperly formatted metadata.",
                       metadata: [#file, #function, #line])
            return nil
        }
        
        let rawFilename = metadata[0] as! String
        let rawFunctionTitle = metadata[1] as! String
        let lineNumber = metadata[2] as! Int
        
        let filePath = rawFilename.components(separatedBy: "/")
        let filename = filePath[filePath.count - 1].components(separatedBy: ".")[0].replacingOccurrences(of: "-", with: "")
        
        let functionTitle = rawFunctionTitle.components(separatedBy: "(")[0].lowercased()
        
        guard let cipheredFilename = filename.lowercased().ciphered(by: 14).randomlyCapitalized(with: lineNumber) else {
            Logger.log("Unable to unwrap ciphered filename.",
                       metadata: [#file, #function, #line])
            return nil
        }
        
        let modelCode = SystemInformation.modelCode.lowercased()
        let operatingSystemVersion = SystemInformation.operatingSystemVersion.lowercased()
        
        if type == .error {
            guard let cipheredFunctionName = functionTitle.lowercased().ciphered(by: 14).randomlyCapitalized(with: lineNumber) else {
                Logger.log("Unable to unwrap ciphered function name.",
                           metadata: [#file, #function, #line])
                return nil
            }
            
            return "\(modelCode).\(cipheredFilename)-\(lineNumber)-\(cipheredFunctionName).\(operatingSystemVersion)"
        } else {
            return "\(modelCode).\(cipheredFilename).\(operatingSystemVersion)"
        }
    }
    
    public func errorCode(metadata: [Any]) -> String {
        guard validateMetadata(metadata) else {
            fatalError("Improperly formatted metadata.")
        }
        
        let fileName = self.fileName(for: metadata[0] as! String)
        let lineNumber = metadata[2] as! Int
        
        var hexArray: [String] = []
        
        for character in fileName.components(separatedBy: "Controller")[0] {
            let stringCharacter = Character(character.uppercased()).asciiValue!
            hexArray.append(String(format: "%02X", stringCharacter))
        }
        
        if hexArray.count > 3 {
            var subsequence = Array(hexArray[0...1])
            subsequence.append(hexArray.last!)
            
            hexArray = subsequence
        }
        
        return "\(hexArray.joined(separator: "")):\(lineNumber)"
    }
    
    public func fileName(for path: String) -> String {
        let filePath = path.components(separatedBy: "/")
        return filePath.last!.components(separatedBy: ".")[0]
    }
    
    public func fileReport(type: ReportType, body: String, prompt: String, extraInfo: String?, metadata: [Any]) {
        var translatedBody = body
        var translatedPrompt = prompt
        
        TranslatorService.main.getTranslations(for: [TranslationInput(body),
                                                     TranslationInput(prompt)],
                                               languagePair: LanguagePair(from: "en",
                                                                          to: languageCode),
                                               requiresHUD: true,
                                               using: .google) { (returnedTranslations,
                                                                  errorDescriptors) in
            guard let translations = returnedTranslations else {
                Logger.log(errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            translatedBody = translations.first(where: { $0.input.value() == translatedBody })?.output ?? translatedBody
            translatedPrompt = translations.first(where: { $0.input.value() == translatedPrompt })?.output ?? translatedPrompt
            
            guard self.validateMetadata(metadata) else {
                Logger.log("Improperly formatted metadata.",
                           metadata: [#file, #function, #line])
                return
            }
            
            guard let code = AKCore.shared.code(for: type, metadata: metadata) else {
                Logger.log("Unable to generate code.",
                           with: .fatalAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            let connectionStatus = hasConnectivity() ? "online" : "offline"
            
            let bodySection = translatedBody.split(separator: ".").count > 1 ? "<i>\(translatedBody.split(separator: ".")[0]).<p></p>\(translatedBody.split(separator: ".")[1]).</i><p></p>" : "<i>\(translatedBody.split(separator: ".")[0]).</i><p></p>"
            
            let compiledRemainder = "<b>Project ID:</b> \(informationDictionary["projectIdentifier"]!)<p></p><b>Build SKU:</b> \(informationDictionary["buildSku"]!)<p></p><b>Occurrence Date:</b> \(secondaryDateFormatter.string(from: Date()))<p></p><b>Internet Connection Status:</b> \(connectionStatus)<p></p>\(extraInfo == nil ? "" : "<b>Extraneous Information:</b> \(extraInfo!)<p></p>")<b>Reference Code:</b> [\(code)]<p></p><b>\(translatedPrompt):</b> "
            
            let subject = "\(buildType == .generalRelease ? finalName : codeName) (\(informationDictionary["bundleVersion"]!)) \(type == .bug ? "Bug" : (type == .error ? "Error" : "Feedback")) Report"
            
            composeMessage(bodySection + compiledRemainder,
                           recipients: ["me@grantbrooks.io"],
                           subject: subject,
                           isHTML: true,
                           metadata: metadata)
        }
    }
    
    private func validateMetadata(_ metadata: [Any]) -> Bool {
        guard metadata.count == 3 else {
            return false
        }
        
        guard metadata[0] is String else {
            return false
        }
        
        guard metadata[1] is String else {
            return false
        }
        
        guard metadata[2] is Int else {
            return false
        }
        
        return true
    }
    
    private func fatalErrorDescriptor(_ description: String) -> String {
        var formattedDescriptor: String! = ""
        
        formattedDescriptor = strippedDescriptor(for: description)
        
        formattedDescriptor = formattedDescriptor.components(separatedBy: CharacterSet.punctuationCharacters).joined()
        
        var intermediateString: String! = ""
        
        if formattedDescriptor.components(separatedBy: " ").count == 1 {
            intermediateString = formattedDescriptor.components(separatedBy: " ")[0]
        } else if formattedDescriptor.components(separatedBy: " ").count == 2 {
            intermediateString = formattedDescriptor.components(separatedBy: " ")[0] + "_" + formattedDescriptor.components(separatedBy: " ")[1]
        } else if formattedDescriptor.components(separatedBy: " ").count > 2 {
            intermediateString = formattedDescriptor.components(separatedBy: " ")[0] + "_" + formattedDescriptor.components(separatedBy: " ")[1] + "_" + formattedDescriptor.components(separatedBy: " ")[2]
        }
        
        formattedDescriptor = "\n\n«" + intermediateString.replacingOccurrences(of: " ", with: "_").uppercased() + "»"
        
        return formattedDescriptor
    }
    
    private func strippedDescriptor(for: String) -> String {
        let stripWords = ["a", "is", "that", "the", "this", "was"]
        
        var resultantString = ""
        
        for word in `for`.components(separatedBy: " ") {
            if !stripWords.contains(word.lowercased()) {
                resultantString.append("\(word)\(word.lowercased() == "not" ? "" : " ")")
            }
        }
        
        return resultantString
    }
}

//==================================================//

/* MARK: - Enumerated Type Declarations */

public enum AKCoreAlertType {
    case connectionAlert
    case expiryAlert
    case fatalErrorAlert
    case feedbackAlert
}

public enum ReportType {
    case bug
    case error
    case feedback
}
