//
//  AKConfirmationAlert.swift
//  AlertKit
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/**
 A highly customizable instance of `UIAlertController` tailored for confirmation of operations.
 */
public class AKConfirmationAlert: AKAlert {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    var confirmButtonTitle: String
    var confirmationStyle: AKActionStyle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(title: String? = nil,
                message: String,
                cancelConfirmTitles: (cancel: String?, confirm: String?)? = nil,
                confirmationStyle: AKActionStyle,
                networkDependent: Bool = false) {
        let cancelButtonTitle = cancelConfirmTitles?.cancel ?? "Cancel"
        let confirmButtonTitle = cancelConfirmTitles?.confirm ?? "Confirm"
        
        self.confirmButtonTitle = confirmButtonTitle
        self.confirmationStyle = confirmationStyle
        
        super.init(title: title,
                   message: message,
                   cancelButtonTitle: cancelButtonTitle,
                   networkDependent: networkDependent)
    }
    
    //==================================================//
    
    /* MARK: - Presentation Function */
    
    /**
     Presents a `UIAlertController` tailored to **confirmation of operations.**
     
     - Parameter completion: Returns `1` upon confirmation, `-1` upon cancellation. Returns `-9` if *networkDependent* is set to `true` and there is no internet connection.
     */
    public override func present(completion: @escaping (_ result: Int) -> Void) {
        translateStrings {
            if self.networkDependent && !hasConnectivity() {
                AKCore.shared.present(.connectionAlert)
                completion(-9)
            }
            
            var alertController: UIAlertController!
            
            if self.title.lowercasedTrimmingWhitespace == "" {
                alertController = UIAlertController(title: self.message,
                                                    message: nil,
                                                    preferredStyle: .alert)
            } else {
                alertController = UIAlertController(title: self.title,
                                                    message: self.message,
                                                    preferredStyle: .alert)
            }
            
            let destructive = self.confirmationStyle == .destructive || self.confirmationStyle == .destructivePreferred ? true : false
            
            let preferred = self.confirmationStyle == .preferred || self.confirmationStyle == .destructivePreferred ? true : false
            
            let confirmAction = UIAlertAction(title: self.confirmButtonTitle,
                                              style: destructive ? .destructive : .default) { _ in
                completion(1)
            }
            
            alertController.addAction(confirmAction)
            
            if preferred {
                alertController.preferredAction = confirmAction
            }
            
            alertController.addAction(UIAlertAction(title: self.cancelButtonTitle,
                                                    style: .cancel) { _ in
                completion(-1)
            })
            
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
                                 TranslationInput(confirmButtonTitle)]
        
        for action in actions {
            inputsToTranslate.append(TranslationInput(action.title))
        }
        
        inputsToTranslate = inputsToTranslate.filter({$0.value().lowercasedTrimmingWhitespace != ""})
        
        dispatchGroup.enter()
        TranslatorService.main.getTranslations(for: inputsToTranslate,
                                               languagePair: LanguagePair(from: "en",
                                                                          to: languageCode),
                                               requiresHUD: true,
                                               using: .google) { (returnedTranslations,
                                                                  errorDescriptors) in
            if let translations = returnedTranslations {
                self.title = translations.first(where: { $0.input.value() == self.title })?.output ?? self.title
                self.message = translations.first(where: { $0.input.value() == self.message })?.output ?? self.message
                self.cancelButtonTitle = translations.first(where: { $0.input.value() == self.cancelButtonTitle })?.output ?? self.cancelButtonTitle
                self.confirmButtonTitle = translations.first(where: { $0.input.value() == self.confirmButtonTitle })?.output ?? self.confirmButtonTitle
                
                for action in self.actions {
                    action.title = translations.first(where: { $0.input.value() == action.title })?.output ?? action.title
                }
            }
            
            if let errors = errorDescriptors {
                Logger.log(errors.keys.joined(separator: "\n"),
                           metadata: [#file, #function, #line])
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
