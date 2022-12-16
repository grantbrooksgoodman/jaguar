//
//  NewChatPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 12/11/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import Translator

public class NewChatPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translator.Translation],
                    contactPairs: [ContactPair])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private let inputs = ["cancel": Translator.TranslationInput("Cancel")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load() {
        state = .loading
        
        let dataModel = PageViewDataModel(inputs: inputs)
        
        dataModel.translateStrings { (returnedTranslations,
                                      returnedException) in
            guard let translations = returnedTranslations else {
                let exception = returnedException ?? Exception(metadata: [#file, #function, #line])
                Logger.log(exception)
                
                self.state = .failed(exception)
                return
            }
            
            ContactService.requestAccess { exception in
                guard exception == nil else {
                    Logger.log(exception!)
                    self.state = .failed(exception!)
                    
                    return
                }
                
                ContactService.loadContacts { contactPairs, exception in
                    guard let pairs = contactPairs else {
                        let error = exception ?? Exception(metadata: [#file, #function, #line])
                        
                        Logger.log(error)
                        self.state = .failed(error)
                        
                        return
                    }
                    
                    self.state = .loaded(translations: translations,
                                         contactPairs: pairs)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - User Prompting */
    
    public func presentExceptionAlert(_ exception: Exception) {
        guard exception.descriptor == "No user exists with the possible hashes." else {
            let translateDescriptor = exception.userFacingDescriptor != exception.descriptor
            AKErrorAlert(error: exception.asAkError(),
                         shouldTranslate: translateDescriptor ? [.all] : [.actions(indices: nil),
                                                                          .cancelButtonTitle]).present()
            return
        }
        
        let alert = AKAlert(message: "It doesn't appear that any of your contacts have an account with us.\n\nWould you like to send them an invite to sign up?",
                            actions: [AKAction(title: "Send Invite",
                                               style: .preferred)])
        alert.present { (actionID) in
            if actionID != -1 {
                self.presentShareSheet()
            }
        }
    }
    
    public func presentShareSheet() {
        let invitationPrompt = "Hey, let's chat on \"Hello\"! It's a simple messaging app that allows us to easily talk to each other in our native languages!"
        guard let invitationURL = URL(string: "http://grantbrooks.io") else { return }
        
        FirebaseTranslator.shared.translate(Translator.TranslationInput(invitationPrompt),
                                            with: Translator.LanguagePair(from: "en",
                                                                          to: RuntimeStorage.languageCode!)) { returnedTranslation, exception in
            guard let translation = returnedTranslation else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                return
            }
            
            MessageComposer.shared.compose(withContent: "\(translation.output)\n\n\(invitationURL.absoluteString)")
        }
    }
}
