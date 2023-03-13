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
    
    /* MARK: - Initializer Method */
    
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
            
            ContactService.loadContacts { contactPairs, exception in
                guard let pairs = contactPairs else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    
                    guard error.isEqual(to: .contactAccessDenied) ||
                            error.isEqual(to: .emptyContactList) ||
                            error.isEqual(to: .noUserWithCallingCode) ||
                            error.isEqual(to: .noUserWithHashes) ||
                            error.isEqual(to: .noUserWithPhoneNumber) ||
                            error.isEqual(to: .noUsersForContacts) else {
                        Logger.log(error)
                        self.state = .failed(error)
                        
                        return
                    }
                    
                    RuntimeStorage.store([], as: .contactPairs)
                    self.state = .loaded(translations: translations,
                                         contactPairs: [])
                    
                    return
                }
                
                RuntimeStorage.store(pairs, as: .contactPairs)
                self.state = .loaded(translations: translations,
                                     contactPairs: pairs)
                
                guard StateProvider.shared.showNewChatPageForGrantedContactAccess else { return }
                Core.gcd.after(seconds: 1) { StateProvider.shared.showNewChatPageForGrantedContactAccess = false }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - User Invitation */
    
    public func presentInvitation() {
        setAppShareLink { exception in
            guard exception == nil,
                  let appShareLink = RuntimeStorage.appShareLink else {
                Logger.log(exception!,
                           with: .errorAlert)
                return
            }
            
            let invitationPrompt = "Hey, let's chat on *\"Hello\"*! It's a simple messaging app that allows us to easily talk to each other in our native languages!"
            
            FirebaseTranslator.shared.translate(Translator.TranslationInput(invitationPrompt),
                                                with: Translator.LanguagePair(from: "en",
                                                                              to: RuntimeStorage.languageCode!),
                                                requiresHUD: true) { returnedTranslation, exception in
                guard let translation = returnedTranslation else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                               with: .errorAlert)
                    return
                }
                
                AnalyticsService.logEvent(.invite)
                MessageComposer.shared.compose(withContent: "\(translation.output)\n\n\(appShareLink.absoluteString)")
            }
        }
    }
    
    private func setAppShareLink(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        if let appShareLink = UserDefaults.standard.value(forKey: "appShareLink") as? URL {
            RuntimeStorage.store(appShareLink, as: .appShareLink)
            completion(nil)
        } else {
            GeneralSerializer.getAppShareLink { link, exception in
                guard let link else {
                    completion(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                RuntimeStorage.store(link, as: .appShareLink)
                UserDefaults.standard.set(RuntimeStorage.appShareLink!, forKey: "appShareLink")
                completion(nil)
            }
        }
    }
}
