//
//  AKTextFieldAlert.swift
//  AlertKit
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/**
 A highly customizable instance of `UIAlertController` tailored for textual input.
 */
public class AKTextFieldAlert: AKAlert {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    var textFieldAttributes: [AKTextFieldAttribute: Any]
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(title: String? = nil,
                message: String,
                actions: [AKAction],
                textFieldAttributes: [AKTextFieldAttribute: Any],
                networkDependent: Bool = false) {
        self.textFieldAttributes = textFieldAttributes
        
        super.init(title: title,
                   message: message,
                   actions: actions,
                   networkDependent: networkDependent)
    }
    
    //==================================================//
    
    /* MARK: - Presentation Function */
    
    public func present(completion: @escaping (_ returnedString: String?, _ actionID: Int) -> Void = { _,_  in }) {
        translateStrings {
            if self.networkDependent && !hasConnectivity() {
                AKCore.shared.present(.connectionAlert)
                completion(nil, -9)
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
            
            var capitalizationType: UITextAutocapitalizationType = .sentences
            var correctionType:     UITextAutocorrectionType     = .default
            var editingMode:        UITextField.ViewMode         = .never
            var keyboardAppearance: UIKeyboardAppearance         = .default
            var keyboardType:       UIKeyboardType               = .default
            var placeholderText                                  = ""
            var sampleText                                       = ""
            var secureTextEntry                                  = false
            var textAlignment:      NSTextAlignment              = .left
            
            for attribute in Array(self.textFieldAttributes.keys) {
                if attribute == .capitalizationType,
                   let specifiedcapitalizationType = self.textFieldAttributes[attribute] as? UITextAutocapitalizationType {
                    capitalizationType = specifiedcapitalizationType
                } else if attribute == .correctionType,
                          let specifiedCorrectionType = self.textFieldAttributes[attribute] as? UITextAutocorrectionType {
                    correctionType = specifiedCorrectionType
                } else if attribute == .editingMode,
                          let specifiedEditingMode = self.textFieldAttributes[attribute] as? UITextField.ViewMode {
                    editingMode = specifiedEditingMode
                } else if attribute == .keyboardAppearance,
                          let specifiedKeyboardAppearance = self.textFieldAttributes[attribute] as? UIKeyboardAppearance {
                    keyboardAppearance = specifiedKeyboardAppearance
                } else if attribute == .keyboardType,
                          let specifiedKeyboardType = self.textFieldAttributes[attribute] as? UIKeyboardType {
                    keyboardType = specifiedKeyboardType
                } else if attribute == .placeholderText,
                          let specifiedPlaceholderText = self.textFieldAttributes[attribute] as? String {
                    placeholderText = specifiedPlaceholderText
                } else if attribute == .sampleText,
                          let specifiedSampleText = self.textFieldAttributes[attribute] as? String {
                    sampleText = specifiedSampleText
                } else if attribute == .secureTextEntry,
                          let specifiedSecureTextEntry = self.textFieldAttributes[attribute] as? Bool {
                    secureTextEntry = specifiedSecureTextEntry
                } else if attribute == .textAlignment,
                          let specifiedTextAlignment = self.textFieldAttributes[attribute] as? NSTextAlignment {
                    textAlignment = specifiedTextAlignment
                }
            }
            
            alertController.addTextField { textField in
                textField.autocapitalizationType = capitalizationType
                textField.autocorrectionType = correctionType
                textField.clearButtonMode = editingMode
                textField.isSecureTextEntry = secureTextEntry
                textField.keyboardAppearance = keyboardAppearance
                textField.keyboardType = keyboardType
                textField.placeholder = placeholderText
                textField.text = sampleText
                textField.textAlignment = textAlignment
            }
            
            for action in self.actions {
                let destructive = action.style == .destructive || action.style == .destructivePreferred ? true : false
                
                let preferred = action.style == .preferred || action.style == .destructivePreferred ? true : false
                
                let alertAction = UIAlertAction(title: action.title,
                                                style: destructive ? .destructive : .default) { _ in
                    completion(alertController.textFields![0].text!, action.identifier)
                }
                
                alertController.addAction(alertAction)
                
                if preferred {
                    alertController.preferredAction = alertAction
                }
            }
            
            let cancelAction = UIAlertAction(title: self.cancelButtonTitle,
                                             style: .cancel) { _ in
                completion(nil, -1)
            }
            
            alertController.addAction(cancelAction)
            
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
        
        if textFieldAttributes.keys.contains(where: { $0 == .placeholderText }) {
            inputsToTranslate.append(TranslationInput(textFieldAttributes[.placeholderText] as! String))
        }
        
        if textFieldAttributes.keys.contains(where: { $0 == .sampleText}) {
            inputsToTranslate.append(TranslationInput(textFieldAttributes[.sampleText] as! String))
        }
        
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
                #warning("Remove this once functionality expanded.")
                //self.title = translations.first(where: { $0.input.value() == self.title })?.output ?? self.title
                self.title = self.title.removingOccurrences(of: ["*"])
                
                self.message = translations.first(where: { $0.input.value() == self.message })?.output ?? self.message
                self.cancelButtonTitle = translations.first(where: { $0.input.value() == self.cancelButtonTitle })?.output ?? self.cancelButtonTitle
                
                if self.textFieldAttributes[.placeholderText] != nil {
                    self.textFieldAttributes[.placeholderText] = translations.first(where: { $0.input.value() == (self.textFieldAttributes[.placeholderText] as! String) })?.output ?? (self.textFieldAttributes[.placeholderText] as! String)
                }
                
                if self.textFieldAttributes[.sampleText] != nil {
                    self.textFieldAttributes[.sampleText] = translations.first(where: { $0.input.value() == (self.textFieldAttributes[.sampleText] as! String) })?.output ?? (self.textFieldAttributes[.sampleText] as! String)
                }
                
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

//==================================================//

/* MARK: - Enumerated Type Declarations */

public enum AKTextFieldAttribute {
    case capitalizationType
    case correctionType
    case editingMode
    case keyboardAppearance
    case keyboardType
    case placeholderText
    case sampleText
    case secureTextEntry
    case textAlignment
}
