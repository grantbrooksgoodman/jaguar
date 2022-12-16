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
    
    public enum ConversationsPageViewNavigationFlowResult {
        case chooseCallingCode(ContactPair, [User])
        case displayError(Exception)
        case handleDuplicates(ContactPair)
        case selectNumber(ContactPair, [User])
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
            case .handleDuplicates(let pair):
                self.handleDuplicates(contactPair: pair) { selectedUser, exception in
                    completion(selectedUser, exception)
                }
            case .startConversation(let pair):
                guard let users = pair.users else {
                    completion(nil, Exception("No users for this «contactPair».",
                                              metadata: [#file, #function, #line]))
                    return
                }
                
                currentlySelectedUser = users[0]
                completion(users[0], nil)
            default:
                completion(nil, Exception("Invalid navigation destination!",
                                          metadata: [#file, #function, #line]))
            }
        }
    }
    
    public static func routeNavigation(with phoneNumber: String,
                                       completion: @escaping(_ selectedUser: User?,
                                                             _ exception: Exception?) -> Void) {
        UserSerializer.shared.findUsers(forPhoneNumbers: phoneNumber.possibleRawNumbers()) { returnedUsers, exception in
            guard let users = returnedUsers else {
                completion(nil, exception ?? Exception("No users found for provided phone number.",
                                                       extraParams: ["PhoneNumber": phoneNumber],
                                                       metadata: [#file, #function, #line]))
                return
            }
            
            let contactPair = ContactPair(contact: Contact(firstName: "",
                                                           lastName: "",
                                                           phoneNumbers: []),
                                          users: users)
            
            self.routeNavigation(with: contactPair) { selectedUser, exception in
                completion(selectedUser, exception)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Flow Determination */
    
    private static func determineDuplicateNavigationFlow(with contactPair: ContactPair,
                                                         completion: @escaping(_ result: ConversationsPageViewNavigationFlowResult) -> Void) {
#warning("This needs a refactor.")
        //multiple users with same raw number
        //first, ask which number to select
        //if selected number that doesn't conflict, just start conversation
        //if selected number that DOES conflict, ask about calling code
        
        guard let users = contactPair.users else {
            completion(.displayError(Exception("No users for this contact pair.",
                                               metadata: [#file, #function, #line])))
            return
        }
        
        // Users whose full phone numbers match a phone number string of the contact. The contact would need to have the calling code.
        let exactMatches = contactPair.exactMatches(withUsers: users)
        
        guard let duplicates = users.rawPhoneNumbers().duplicates else {
            completion(.displayError(Exception("No duplicate phone numbers among the provided users.",
                                               extraParams: ["RawPhoneNumbers": users.rawPhoneNumbers()],
                                               metadata: [#file, #function, #line])))
            return
        }
        
        if exactMatches.rawPhoneNumbers().containsAll(in: duplicates) {
            //have exact matches, so just prompt for number
            
            var partialMatches = users.filter({ !exactMatches.identifiers().contains($0.identifier) })
            partialMatches = partialMatches.filter({ !exactMatches.rawPhoneNumbers().contains($0.phoneNumber) })
            
            if partialMatches.count == 0 {
                print("MAY HAVE 2 NUMBERS, ONE OF WHICH IS AN EXACT MATCH, AND THE OTHER IS THE SAME BUT WITHOUT CALLING CODE")
            }
            
            partialMatches.append(contentsOf: exactMatches)
            
            guard !partialMatches.isEmpty else {
                completion(.displayError(Exception("No partial matches!",
                                                   metadata: [#file, #function, #line])))
                return
            }
            
            guard partialMatches.count > 1 else {
                completion(.startConversation(ContactPair(contact: contactPair.contact,
                                                          users: [partialMatches[0]])))
                return
            }
            
            if exactMatches.identifiers() != partialMatches.identifiers() {
                Logger.log("«exactMatches» and «partialMatches» are different.",
                           with: .normalAlert,
                           verbose: false /*true*/,
                           metadata: [#file, #function, #line])
            }
            
            completion(.selectNumber(contactPair, partialMatches))
        } else {
            //now select number
            //if number is the conflicting one, follow up with ask
            var phoneNumbers = [String]()
            
            let uniqueUsers = users.filter({ !duplicates.contains($0.phoneNumber) })
            uniqueUsers.forEach { user in
                phoneNumbers.append("+\(user.callingCode!) \(user.phoneNumber.formattedPhoneNumber(region: user.region))")
            }
            
            phoneNumbers.append(contentsOf: duplicates)
            
            guard !phoneNumbers.isEmpty else {
                completion(.displayError(Exception("No phone numbers!",
                                                   metadata: [#file, #function, #line])))
                return
            }
            
            guard phoneNumbers.count > 1 else {
                guard users.callingCodes().unique().count == users.callingCodes().count else {
                    print("users both have same calling code... what? should be unique")
                    
                    completion(.startConversation(ContactPair(contact: contactPair.contact,
                                                              users: [users[0]])))
                    return
                }
                
                completion(.chooseCallingCode(contactPair, users))
                return
            }
            
            presentSelectNumberActionSheet(contactPair: contactPair,
                                           phoneNumbers: phoneNumbers) { selectedPhoneNumber, exception in
                guard let phoneNumber = selectedPhoneNumber else {
                    completion(.displayError(exception ?? Exception(metadata: [#file, #function, #line])))
                    return
                }
                
                if duplicates.contains(phoneNumber) {
                    //wants to start with conflicting number
                    let filteredUsers = users.filter({ $0.phoneNumber == phoneNumber })
                    
                    completion(.chooseCallingCode(contactPair, filteredUsers))
                } else if let filteredUser = users.filter({ phoneNumber.possibleRawNumbers().contains($0.phoneNumber) }).first {
                    completion(.startConversation(ContactPair(contact: contactPair.contact,
                                                              users: [filteredUser])))
                } else {
                    completion(.displayError(Exception("Duplicates doesn't contain phone number, and there's no filtered user.", metadata: [#file, #function, #line])))
                }
            }
        }
    }
    
    private static func determineNavigationFlow(with contactPair: ContactPair,
                                                completion: @escaping(_ result: ConversationsPageViewNavigationFlowResult) -> Void) {
        guard let users = contactPair.users else {
            completion(.displayError(Exception("No users for this contact pair.",
                                               extraParams: ["ContactPairHash": contactPair.contact.hash],
                                               metadata: [#file, #function, #line])))
            return
        }
        
        guard users.rawPhoneNumbers().unique() == users.rawPhoneNumbers() else {
            completion(.handleDuplicates(contactPair))
            return
        }
        
        if users.rawPhoneNumbers().unique().count > 1 {
            //Contact has multiple valid numbers
            
            if users.rawPhoneNumbers().unique() != users.rawPhoneNumbers() {
                completion(.handleDuplicates(contactPair))
            } else {
                //just need to select the number to use
                completion(.selectNumber(contactPair, users))
            }
        } else {
            //one valid number, matches with one on server, just start conversation
            let userToStartWith = contactPair.exactMatches(withUsers: users).first ?? users[0]
            
            RuntimeStorage.currentUser!.canStartConversation(with: userToStartWith) { canStart, exception in
                if canStart {
                    completion(.startConversation(contactPair))
                } else {
                    completion(.displayError(exception ?? Exception(metadata: [#file, #function, #line])))
                }
            }
        }
    }
    
    private static func handleDuplicates(contactPair: ContactPair,
                                         completion: @escaping(_ selectedUser: User?,
                                                               _ exception: Exception?) -> Void) {
        determineDuplicateNavigationFlow(with: contactPair) { result in
            switch result {
            case .displayError(let exception):
                currentlySelectedUser = nil
                completion(nil, exception)
            case .handleDuplicates(let contactPair):
                self.handleDuplicates(contactPair: contactPair) { selectedUser, exception in
                    completion(selectedUser, exception)
                }
            case .chooseCallingCode(let contactPair, let users):
                self.presentSelectCallingCodeActionSheet(contactPair: contactPair, users: users) { selectedUser, exception in
                    completion(selectedUser, exception)
                }
            case .selectNumber(let contactPair, let users):
                self.presentSelectNumberActionSheet(contactPair: contactPair, users: users) { selectedUser, exception in
                    completion(selectedUser, exception)
                }
            case .startConversation(let contactPair):
                self.routeNavigation(with: contactPair) { selectedUser, exception in
                    completion(selectedUser, exception)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - User Prompting */
    
    private static func presentSelectCallingCodeActionSheet(contactPair: ContactPair,
                                                            users: [User],
                                                            completion: @escaping(_ selectedUser: User?,
                                                                                  _ exception: Exception?) -> Void) {
        let originalPrompt = "It appears there may be multiple users with \(contactPair.contact.firstName) \(contactPair.contact.lastName)'s phone number. To continue, please select the calling code of \(contactPair.contact.firstName)'s number."
        
        let messageInput = Translator.TranslationInput(originalPrompt, alternate: "It appears there may be multiple users with this phone number. To continue, please select the appropriate calling code.")
        
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
            
            for user in users {
                let userAction = UIAlertAction(title: RegionDetailServer.getRegionTitle(forCallingCode: user.callingCode),
                                               style: .default) { _ in
                    self.routeNavigation(with: ContactPair(contact: contactPair.contact,
                                                           users: [user])) { selectedUser, exception in
                        completion(selectedUser, exception)
                    }
                }
                
                alertController.addAction(userAction)
            }
            
            let cancelAction = UIAlertAction(title: cancel.output,
                                             style: .cancel) { _ in
                //                completion(nil)
            }
            
            alertController.addAction(cancelAction)
            
            Core.ui.present(viewController: alertController)
        }
    }
    
    private static func presentSelectNumberActionSheet(contactPair: ContactPair,
                                                       phoneNumbers: [String],
                                                       completion: @escaping(_ selectedPhoneNumber: String?,
                                                                             _ exception: Exception?) -> Void) {
        let originalPrompt = "Which of \(contactPair.contact.firstName)'s numbers would you like to use to start this conversation?"
        
        let messageInput = Translator.TranslationInput(originalPrompt,
                                                       alternate: "Select which number you would like to use to start this conversation.")
        
        FirebaseTranslator.shared.getTranslations(for: [Translator.TranslationInput("Select Number"),
                                                        messageInput,
                                                        Translator.TranslationInput("Cancel")],
                                                  languagePair: Translator.LanguagePair(from: "en", to: RuntimeStorage.languageCode!)) { returnedTranslations, exception in
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
            
            for phoneNumber in phoneNumbers {
                var label = ""
                
                if let contactLabel = contactPair.contact.phoneNumbers.first(where: { $0.digits.possibleRawNumbers().contains(phoneNumber) })?.label {
                    label = "\(contactLabel) – "
                }
                
                let userAction = UIAlertAction(title: "\(label)\(phoneNumber)",
                                               style: .default) { _ in
                    completion(phoneNumber, nil)
                }
                
                alertController.addAction(userAction)
            }
            
            let cancelAction = UIAlertAction(title: cancel.output,
                                             style: .cancel) { _ in
                //                completion(nil)
            }
            
            alertController.addAction(cancelAction)
            
            Core.ui.present(viewController: alertController)
        }
    }
    
    private static func presentSelectNumberActionSheet(contactPair: ContactPair,
                                                       users: [User],
                                                       completion: @escaping(_ selectedUser: User?,
                                                                             _ exception: Exception?) -> Void) {
        let originalPrompt = "Which of \(contactPair.contact.firstName)'s numbers would you like to use to start this conversation?"
        
        let messageInput = Translator.TranslationInput(originalPrompt, alternate: "Select which number you would like to use to start this conversation.")
        
        FirebaseTranslator.shared.getTranslations(for: [TranslationInput("Select Number"),
                                                        messageInput,
                                                        TranslationInput("Cancel")],
                                                  languagePair: LanguagePair(from: "en", to: RuntimeStorage.languageCode!)) { returnedTranslations, exception in
            guard let translations = returnedTranslations else {
                completion(nil, exception ?? Exception("No translations returned.",
                                                       metadata: [#file, #function, #line]))
                return
            }
            
            guard let title = translations.first(where: { $0.input.value() == "Select Number" }),
                  let message = translations.first(where: { $0.input.value() == messageInput.value() }),
                  let cancel = translations.first(where: { $0.input.value() == "Cancel" }) else { return }
            
            let alertController = UIAlertController(title: title.output,
                                                    message: message.output,
                                                    preferredStyle: .actionSheet)
            
            for user in users {
                let userAction = UIAlertAction(title: "+\(user.callingCode!) \(user.phoneNumber.formattedPhoneNumber(region: RegionDetailServer.getRegionCode(forCallingCode: user.callingCode)))",
                                               style: .default) { _ in
                    self.routeNavigation(with: ContactPair(contact: contactPair.contact,
                                                           users: [user])) { selectedUser, exception in
                        completion(selectedUser, exception)
                    }
                }
                
                alertController.addAction(userAction)
            }
            
            let cancelAction = UIAlertAction(title: cancel.output,
                                             style: .cancel) { _ in
                //                completion(nil)
            }
            
            alertController.addAction(cancelAction)
            
            Core.ui.present(viewController: alertController)
        }
    }
}
