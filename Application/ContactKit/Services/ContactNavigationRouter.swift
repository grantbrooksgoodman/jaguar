//
//  ContactNavigationRouter.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/11/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import Translator

public struct ContactNavigationRouter {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static var currentlySelectedUser: User?
    
    public enum ContactNavigationFlowResult {
        case displayError(Exception)
        
        case selectCallingCode(ContactPair)
        case selectNumber(ContactPair)
        
        case startConversation(ContactPair)
    }
    
    //==================================================//
    
    /* MARK: - Navigation Routing */
    
    public static func routeNavigation(with contactPair: ContactPair,
                                       completion: @escaping(_ selectedUser: User?,
                                                             _ exception: Exception?) -> Void) {
        determineNavigationFlow(with: contactPair) { result in
            switch result {
            case .displayError(let exception):
                currentlySelectedUser = nil
                completion(nil, exception)
            case .selectCallingCode(let contactPair):
                self.presentSelectCallingCodeActionSheet(contactPair: contactPair) { selectedPair, exception in
                    guard let selectedPair else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    routeNavigation(with: ContactPair(contact: contactPair.contact,
                                                      numberPairs: [selectedPair])) { selectedUser, exception in
                        completion(selectedUser, exception)
                    }
                }
            case .selectNumber(let contactPair):
                self.presentSelectNumberActionSheet(contactPair: contactPair) { selectedPair, exception in
                    guard let selectedPair else {
                        completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    routeNavigation(with: ContactPair(contact: contactPair.contact,
                                                      numberPairs: [selectedPair])) { selectedUser, exception in
                        completion(selectedUser, exception)
                    }
                }
            case .startConversation(let contactPair):
                guard let user = contactPair.numberPairs?[0].users[0] else {
                    completion(nil, Exception("No number pairs/users for this contact pair.",
                                              extraParams: ["ContactPairHash": contactPair.contact.hash],
                                              metadata: [#file, #function, #line]))
                    return
                }
                
                currentlySelectedUser = user
                completion(user, nil)
            }
        }
    }
    
    public static func routeNavigation(with phoneNumber: String,
                                       completion: @escaping(_ selectedUser: User?,
                                                             _ exception: Exception?) -> Void) {
        UserSerializer.shared.findUsers(for: phoneNumber) { users, exception in
            guard let users else {
                completion(nil, exception ?? Exception("No users found for provided phone number.",
                                                       extraParams: ["PhoneNumber": phoneNumber],
                                                       metadata: [#file, #function, #line]))
                return
            }
            
            let numberPair = NumberPair(number: phoneNumber, users: users)
            let contactPair = ContactPair(contact: Contact.empty(), numberPairs: [numberPair])
            
            self.routeNavigation(with: contactPair) { selectedUser, exception in
                completion(selectedUser, exception)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Flow Determination */
    
    private static func determineNavigationFlow(with contactPair: ContactPair,
                                                completion: @escaping(_ result: ContactNavigationFlowResult) -> Void) {
        let noUserException = Exception("No users for this contact pair.",
                                        extraParams: ["ContactPairHash": contactPair.contact.hash],
                                        metadata: [#file, #function, #line])
        
        guard let numberPairs = contactPair.numberPairs,
              !numberPairs.isEmpty else {
            completion(.displayError(noUserException))
            return
        }
        
        /* if have multiple number pairs, that means one contact has
         multiple accounts under different numbers */
        guard numberPairs.count == 1 else {
            completion(.selectNumber(contactPair))
            return
        }
        
        let numberPair = numberPairs[0]
        guard !numberPair.users.isEmpty else {
            completion(.displayError(noUserException))
            return
        }
        
        /* one account for this contact */
        guard numberPair.users.count == 1 else {
            /* if have multiple users, that means the contact has a phone number
             without a calling code, and there are multiple matches on the server
             for that number */
            completion(.selectCallingCode(contactPair))
            return
        }
        
        /* one account for this contact, and one user – start conversation */
        
        guard let currentUser = RuntimeStorage.currentUser else {
            completion(.displayError(Exception("No current user!",
                                               metadata: [#file, #function, #line])))
            return
        }
        
        currentUser.canStartConversation(with: numberPairs.users[0]) { canStart, exception in
            guard canStart else {
                completion(.displayError(exception ?? Exception("Can't start conversation.",
                                                                metadata: [#file, #function, #line])))
                return
            }
            
            completion(.startConversation(contactPair))
        }
    }
    
    //==================================================//
    
    /* MARK: - User Prompting */
    
    private static func presentSelectCallingCodeActionSheet(contactPair: ContactPair,
                                                            completion: @escaping(_ selectedPair: NumberPair?,
                                                                                  _ exception: Exception?) -> Void) {
        guard let numberPairs = contactPair.numberPairs,
              numberPairs.count == 1 else {
            completion(nil, Exception("Either no number pairs, or more than one for this contact pair.",
                                      extraParams: ["NumberPairsCount": contactPair.numberPairs?.count ?? 0],
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let alternatePrompt = "It appears there may be multiple users with this phone number. To continue, please select the appropriate calling code."
        
        var originalPrompt = "It appears there may be multiple users with \(contactPair.contact.firstName) \(contactPair.contact.lastName)'s phone number. To continue, please select the calling code of \(contactPair.contact.firstName)'s number."
        originalPrompt = contactPair.contact.firstName.lowercasedTrimmingWhitespace == "" ? alternatePrompt : originalPrompt
        
        let messageInput = TranslationInput(originalPrompt,
                                            alternate: alternatePrompt)
        
        FirebaseTranslator.shared.getTranslations(for: [TranslationInput("Select Region"),
                                                        messageInput,
                                                        TranslationInput("Cancel")],
                                                  languagePair: LanguagePair(from: "en", to: RuntimeStorage.languageCode!)) { returnedTranslations, exception in
            guard let translations = returnedTranslations else {
                completion(nil, exception ?? Exception("No translations returned.",
                                                       metadata: [#file, #function, #line]))
                return
            }
            
            guard let title = translations.first(where: { $0.input.value() == "Select Region" }),
                  let message = translations.first(where: { $0.input.value() == messageInput.value() }),
                  let cancel = translations.first(where: { $0.input.value() == "Cancel" }) else { return }
            
            let alertController = UIAlertController(title: title.output,
                                                    message: message.output,
                                                    preferredStyle: .actionSheet)
            
            for user in numberPairs[0].users.sorted(by: { $0.callingCode < $1.callingCode }) {
                let userAction = UIAlertAction(title: RegionDetailServer.getRegionTitle(forCallingCode: user.callingCode),
                                               style: .default) { _ in
                    completion(NumberPair(number: numberPairs[0].number,
                                          users: [user]), nil)
                }
                
                alertController.addAction(userAction)
            }
            
            let cancelAction = UIAlertAction(title: cancel.output, style: .cancel)
            alertController.addAction(cancelAction)
            
            Core.ui.present(viewController: alertController)
        }
    }
    
    private static func presentSelectNumberActionSheet(contactPair: ContactPair,
                                                       completion: @escaping(_ selectedPair: NumberPair?,
                                                                             _ exception: Exception?) -> Void) {
        guard let numberPairs = contactPair.numberPairs else {
            completion(nil, Exception("No number pairs for this contact!",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        let alternatePrompt = "Select which number you would like to use to start this conversation."
        
        var originalPrompt = "Which of \(contactPair.contact.firstName)'s numbers would you like to use to start this conversation?"
        originalPrompt = contactPair.contact.firstName.lowercasedTrimmingWhitespace == "" ? alternatePrompt : originalPrompt
        
        let messageInput = TranslationInput(originalPrompt,
                                            alternate: alternatePrompt)
        
        FirebaseTranslator.shared.getTranslations(for: [TranslationInput("Select Number"),
                                                        messageInput,
                                                        TranslationInput("Cancel")],
                                                  languagePair: LanguagePair(from: "en", to: RuntimeStorage.languageCode!)) { returnedTranslations, exception in
            guard let translations = returnedTranslations else {
                completion(nil, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard let title = translations.first(where: { $0.input.value() == "Select Number" }),
                  let message = translations.first(where: { $0.input.value() == messageInput.value() }),
                  let cancel = translations.first(where: { $0.input.value() == "Cancel" }) else { return }
            
            let alertController = UIAlertController(title: title.output,
                                                    message: message.output,
                                                    preferredStyle: .actionSheet)
            
            for pair in numberPairs.sorted(by: { $0.number < $1.number }) {
                var label = ""
                
                if let contactLabel = contactPair.contact.phoneNumbers.first(where: { $0.digits.contains(pair.number) })?.label {
                    label = "\(contactLabel) – "
                }
                
                let userAction = UIAlertAction(title: "\(label)\(pair.number!.phoneNumberFormatted)",
                                               style: .default) { _ in
                    completion(pair, nil)
                }
                
                alertController.addAction(userAction)
            }
            
            let cancelAction = UIAlertAction(title: cancel.output, style: .cancel)
            alertController.addAction(cancelAction)
            
            Core.ui.present(viewController: alertController)
        }
    }
}
