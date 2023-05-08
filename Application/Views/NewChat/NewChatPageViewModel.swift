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

public class NewChatPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(contactPairs: [ContactPair])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Published private(set) var state = State.idle
    
    //==================================================//
    
    /* MARK: - Initializer Method */
    
    public func load() {
        state = .loading
        
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
                self.state = .loaded(contactPairs: [])
                
                return
            }
            
            RuntimeStorage.store(pairs, as: .contactPairs)
            self.state = .loaded(contactPairs: pairs)
            
            guard StateProvider.shared.showNewChatPageForGrantedContactAccess else { return }
            Core.gcd.after(seconds: 1) { StateProvider.shared.showNewChatPageForGrantedContactAccess = false }
        }
    }
}
