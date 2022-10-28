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
import AlertKit
import Translator

public class NewConversationPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translator.Translation],
                    contacts: [ContactPair])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Published var contacts = [ContactPair]()
    
    private let inputs = ["search": Translator.TranslationInput("Search")]
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load() {
        state = .loading
        
        let dataModel = PageViewDataModel(inputs: inputs)
        
        let metadata: [Any] = [#file, #function, #line]
        let timeout = Timeout(alertingAfter: 10, metadata: metadata) {
            self.state = .failed(Exception("The operation timed out. Please try again later.",
                                           metadata: metadata))
        }
        
        dataModel.translateStrings { (returnedTranslations,
                                      returnedException) in
            guard let translations = returnedTranslations else {
                let exception = returnedException ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(exception)
                self.state = .failed(exception)
                
                return
            }
            
            self.loadContacts { contactPairs, exception in
                timeout.cancel()
                
                guard let pairs = contactPairs else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    
                    Logger.log(error)
                    self.state = .failed(error)
                    
                    return
                }
                
                self.state = .loaded(translations: translations,
                                     contacts: pairs)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Contact Processing */
    
    public func loadContacts(completion: @escaping(_ contactPairs: [ContactPair]?,
                                                   _ exception: Exception?) -> Void) {
        let sorted = ContactService.fetchAllContacts().sorted
        guard var contactsToReturn = sorted[0] as? [ContactPair],
              let contactsToFetch = sorted[1] as? [Contact] else {
            let exception = Exception("Unable to sort contacts.",
                                      metadata: [#file, #function, #line])
            
            Logger.log(exception, with: .errorAlert)
            completion(nil, exception)
            
            return
        }
        
        UserSerializer.shared.findUsers(forContacts: contactsToFetch) { returnedContactPairs, exception in
            guard let contactPairs = returnedContactPairs else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                
                let isEmpty = contactsToReturn.uniquePairs.isEmpty
                completion(isEmpty ? nil : contactsToReturn.uniquePairs,
                           isEmpty ? exception ?? Exception(metadata: [#file, #function, #line]) : nil)
                return
            }
            
            ContactArchiver.addToArchive(contactPairs)
            contactsToReturn.append(contentsOf: contactPairs)
            
            completion(contactsToReturn.uniquePairs, nil)
        }
    }
    
    public func requestAccess() {
        let contactStore = CNContactStore()
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            self.synchronizeContacts()
        case .denied:
            contactStore.requestAccess(for: .contacts) { granted,
                error in
                guard granted else {
                    Logger.log(error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!, metadata: [#file, #function, #line]), with: .errorAlert)
                    return
                }
                
                self.synchronizeContacts()
            }
        case .restricted, .notDetermined:
            contactStore.requestAccess(for: .contacts) { granted,
                error in
                
                guard granted else {
                    Logger.log(error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!, metadata: [#file, #function, #line]), with: .errorAlert)
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
        let sorted = ContactService.fetchAllContacts().sorted
        guard var contactsToReturn = sorted[0] as? [ContactPair],
              let contactsToFetch = sorted[1] as? [Contact] else {
            Logger.log("Unable to sort contacts.",
                       with: .errorAlert,
                       metadata: [#file, #function, #line])
            return
        }
        
        self.contacts = contactsToReturn
        
        UserSerializer.shared.findUsers(forContacts: contactsToFetch) { returnedContactPairs, exception in
            guard let contactPairs = returnedContactPairs else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                return
            }
            
            ContactArchiver.addToArchive(contactPairs)
            contactsToReturn.append(contentsOf: contactPairs)
            
            self.contacts = contactsToReturn.uniquePairs
        }
    }
}
