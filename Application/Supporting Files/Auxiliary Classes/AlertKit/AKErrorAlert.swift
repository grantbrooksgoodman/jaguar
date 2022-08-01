//
//  AKErrorAlert.swift
//  AlertKit
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import Translator

/**
 A highly customizable instance of `UIAlertController` tailored for displaying error information.
 */
public class AKErrorAlert: AKAlert {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Strings
    var fileReportString = "File Report..."
    
    //Other Declarations
    let error: AKError
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(message: String? = nil,
                error: AKError,
                actions: [AKAction]? = nil,
                networkDependent: Bool = false) {
        self.error = error
        
        let errorMessage = message ?? error.description ?? "Unfortunately, an undocumented error has occurred.\n\nNo additional information is available at this time.\n\nIt may be possible to continue working normally, however it is strongly recommended to exit the application to prevent further error or possible data corruption."
        
        super.init(message: errorMessage,
                   actions: actions,
                   cancelButtonTitle: "Dismiss",
                   networkDependent: networkDependent)
        
    }
    
    //==================================================//
    
    /* MARK: - Presentation Function */
    
    public override func present(completion: @escaping (Int) -> Void = { _ in }) {
        translateStrings {
            guard self.error.metadata.count == 3,
                  self.error.metadata[0] is String,
                  self.error.metadata[1] is String,
                  self.error.metadata[2] is Int else {
                Logger.log("Improperly formatted metadata.",
                           metadata: [#file, #function, #line])
                return
            }
            
            var alertController: UIAlertController!
            
            guard self.title.lowercasedTrimmingWhitespace == "" else {
                Logger.log("AKErrorAlerts may not have custom titles.",
                           with: .fatalAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            #warning("Decide on if you want to keep this.")
            alertController = UIAlertController(title: self.message /*self.message.appending("\n\n[\(self.error.code)]")*/,
                                                message: "\n[\(self.error.code)]",
                                                preferredStyle: .alert)
            
            for action in self.actions {
                let destructive = action.style == .destructive || action.style == .destructivePreferred ? true : false
                
                let preferred = action.style == .preferred || action.style == .destructivePreferred ? true : false
                
                let alertAction = UIAlertAction(title: action.title,
                                                style: destructive ? .destructive : .default) { _ in
                    completion(action.identifier)
                }
                
                alertController.addAction(alertAction)
                
                if preferred {
                    alertController.preferredAction = alertAction
                }
            }
            
            if self.error.isReportable {
                alertController.addAction(UIAlertAction(title: self.fileReportString, style: .default, handler: { (_: UIAlertAction!) in
                    let fileName = AKCore.shared.fileName(for: self.error.metadata[0] as! String)
                    
                    let functionName = (self.error.metadata[1] as! String).components(separatedBy: "(")[0]
                    
                    AKCore.shared.fileReport(type: .error, body: "Appended below are various data points useful in determining the cause of the error encountered. Please do not edit the information contained in the lines below.", prompt: "Error Descriptor", extraInfo: self.error.description, metadata: [fileName, functionName, self.error.metadata[2]])
                }))
            }
            
            alertController.addAction(UIAlertAction(title: self.cancelButtonTitle,
                                                    style: .cancel))
            
            politelyPresent(viewController: alertController)
        }
    }
    
    //==================================================//
    
    /* MARK: - Translation Function */
    
    private func translateStrings(completion: @escaping() -> Void) {
        let dispatchGroup = DispatchGroup()
        var leftDispatchGroup = false
        
        var inputsToTranslate = [TranslationInput(title),
                                 TranslationInput(message),
                                 TranslationInput(cancelButtonTitle),
                                 TranslationInput(fileReportString)]
        
        for action in actions {
            inputsToTranslate.append(TranslationInput(action.title))
        }
        
        inputsToTranslate = inputsToTranslate.filter({$0.value() != ""})
        
        dispatchGroup.enter()
        FirebaseTranslator.shared.getTranslations(for: inputsToTranslate,
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
            
            self.title = translations.first(where: { $0.input.value() == self.title })?.output ?? self.title
            self.message = translations.first(where: { $0.input.value() == self.message })?.output ?? self.message
            self.cancelButtonTitle = translations.first(where: { $0.input.value() == self.cancelButtonTitle })?.output ?? self.cancelButtonTitle
            self.fileReportString = translations.first(where: { $0.input.value() == self.fileReportString })?.output ?? self.fileReportString
            
            for action in self.actions {
                action.title = translations.first(where: { $0.input.value() == action.title })?.output ?? action.title
            }
            
            if !leftDispatchGroup {
                dispatchGroup.leave()
                leftDispatchGroup = true
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }
}

//==================================================//

/* MARK: - AKError */

public struct AKError {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Strings
    let code: String
    var description: String?
    
    //Other Declarations
    var isReportable: Bool
    var metadata: [Any]
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(_ description: String? = nil, metadata: [Any], isReportable: Bool) {
        self.description = description
        self.metadata = metadata
        self.isReportable = isReportable
        
        self.code = AKCore.shared.errorCode(metadata: metadata)
    }
}
