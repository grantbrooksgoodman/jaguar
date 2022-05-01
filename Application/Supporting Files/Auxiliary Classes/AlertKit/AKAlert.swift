//
//  AKAlert.swift
//  AlertKit
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/**
 A highly customizable instance of `UIAlertController`.
 */
public class AKAlert {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Booleans
    var networkDependent: Bool
    var showsCancelButton: Bool
    
    //Strings
    var cancelButtonTitle: String
    var message: String
    var title: String
    
    //Other Declarations
    var actions: [AKAction]
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(title: String? = nil,
                message: String,
                actions: [AKAction]? = nil,
                showsCancelButton: Bool? = nil,
                cancelButtonTitle: String? = nil,
                networkDependent: Bool = false) {
        self.title = title ?? ""
        self.message = message
        self.showsCancelButton = showsCancelButton ?? true
        self.cancelButtonTitle = cancelButtonTitle ?? "Cancel"
        self.networkDependent = networkDependent
        
        guard let unwrappedActions = actions else {
            self.actions = []
            return
        }
        
        guard unwrappedActions.filter({$0.style == .preferred || $0.style == .destructivePreferred}).count < 2 else {
            fatalError("Invalid action schema! Actions must contain only one of which is preferred.")
        }
        
        self.actions = unwrappedActions
    }
    
    //==================================================//
    
    /* MARK: - Setter Functions */
    
    public func setActions(_ actions: [AKAction]) {
        guard actions.filter({$0.style == .preferred || $0.style == .destructivePreferred}).count < 2 else {
            fatalError("Invalid action schema! Actions must contain only one of which is preferred.")
        }
        
        self.actions = actions
    }
    
    //==================================================//
    
    /* MARK: - Presentation Function */
    
    public func present(completion: @escaping (_ actionID: Int) -> Void = { _ in }) {
        translateStrings {
            if self.networkDependent && !hasConnectivity() {
                AKCore.shared.present(.connectionAlert)
                completion(-9)
            }
            
            var alertController: UIAlertController!
            
            if self.title.lowercasedTrimmingWhitespace == "" {
                alertController = UIAlertController(title: nil,
                                                    message: self.message,
                                                    preferredStyle: .alert)
            } else {
                alertController = UIAlertController(title: self.title,
                                                    message: self.message,
                                                    preferredStyle: .alert)
            }
            
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
            
            let cancelAction = UIAlertAction(title: self.cancelButtonTitle,
                                             style: .cancel) { _ in
                completion(-1)
            }
            
            if self.showsCancelButton {
                alertController.addAction(cancelAction)
            }
            
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
                                 TranslationInput(cancelButtonTitle)]
        
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
                
                for action in self.actions {
                    action.title = translations.first(where: { $0.input.value() == action.title })?.output ?? action.title
                }
            }
            
            if let errors = errorDescriptors {
                log(errors.keys.joined(separator: "\n"),
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
