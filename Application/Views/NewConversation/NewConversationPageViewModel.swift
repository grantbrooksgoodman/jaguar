//
//  NewConversationPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/09/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import ContactsUI
import SwiftUI

/* Third-party Frameworks */
import Translator

public class NewConversationPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(String)
        case loaded(translations: [String: Translation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Published var contacts = [ContactPair]()
    
    private let inputs = ["search": TranslationInput("Search")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load() {
        state = .loading
        
        let dataModel = PageViewDataModel(inputs: inputs)
        
        dataModel.translateStrings { (returnedTranslations,
                                      errorDescriptor) in
            guard let translations = returnedTranslations else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                
                self.state = .failed(error)
                return
            }
            
            self.state = .loaded(translations: translations)
        }
    }
    
    //==================================================//
    
    /* MARK: - Contact Processing */
    
    public func requestAccess() {
        let contactStore = CNContactStore()
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            self.synchronizeContacts()
        case .denied:
            contactStore.requestAccess(for: .contacts) { granted,
                error in
                guard granted else {
                    Logger.log(error == nil ? "An unknown error occurred." : Logger.errorInfo(error!),
                               with: .errorAlert,
                               metadata: [#file, #function, #line])
                    return
                }
                
                self.synchronizeContacts()
            }
        case .restricted, .notDetermined:
            contactStore.requestAccess(for: .contacts) { granted,
                error in
                
                guard granted else {
                    Logger.log(error == nil ? "An unknown error occurred." : Logger.errorInfo(error!),
                               with: .errorAlert,
                               metadata: [#file, #function, #line])
                    return
                }
                
                self.synchronizeContacts()
            }
        @unknown default:
            Logger.log("An unknown error occurred.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
        }
    }
    
    public func synchronizeContacts() {
        let sorted = UserSerializer.shared.sortContacts(ContactService.fetchAllContacts())
        guard var contactsToReturn = sorted[0] as? [ContactPair],
              let contactsToFetch = sorted[1] as? [Contact] else {
            Logger.log("Unable to sort contacts.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        self.contacts = contactsToReturn
        
        UserSerializer.shared.validUsers(fromContacts: contactsToFetch) { returnedContactPairs, errorDescriptor in
            guard let contactPairs = returnedContactPairs else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
                return
            }
            
            ContactArchiver.addToArchive(contactPairs)
            contactsToReturn.append(contentsOf: contactPairs)
            
            self.contacts = contactsToReturn.uniquePairs
        }
    }
}
