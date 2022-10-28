//
//  ConversationsPageViewDataModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import Translator

public class ConversationsPageViewDataModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Enums
    public enum ConversationsPageViewNavigationFlowResult {
        case chooseCallingCode(ContactPair, [User])
        case displayError(Exception)
        case handleDuplicates(ContactPair, [User])
        case selectNumber(ContactPair, [User])
        case startConversation(ContactPair)
    }
    
    //==================================================//
    
    /* MARK: - Navigation Routing */
    
    public func handleDuplicates(contactPair: ContactPair,
                                 users: [User],
                                 completion: @escaping(_ result: ConversationsPageViewNavigationFlowResult) -> Void) {
#warning("This needs a refactor.")
        //multiple users with same raw number
        //first, ask which number to select
        //if selected number that doesn't conflict, just start conversation
        //if selected number that DOES conflict, ask about calling code
        
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
    
    public func routeNavigation(withContactPair: ContactPair,
                                completion: @escaping(_ result: ConversationsPageViewNavigationFlowResult) -> Void) {
        guard let users = withContactPair.users else {
            completion(.displayError(Exception("No users for this contact pair.",
                                               extraParams: ["ContactPairHash": withContactPair.contact.hash],
                                               metadata: [#file, #function, #line])))
            return
        }
        
        guard users.rawPhoneNumbers().unique() == users.rawPhoneNumbers() else {
            completion(.handleDuplicates(withContactPair, users))
            return
        }
        
        if users.rawPhoneNumbers().unique().count > 1 {
            //Contact has multiple valid numbers
            
            if users.rawPhoneNumbers().unique() != users.rawPhoneNumbers() {
                completion(.handleDuplicates(withContactPair, users))
            } else {
                //just need to select the number to use
                completion(.selectNumber(withContactPair, users))
            }
        } else {
            guard users.rawPhoneNumbers().unique() == users.rawPhoneNumbers() else {
                completion(.handleDuplicates(withContactPair, users))
                return
            }
            
            //one valid number, matches with one on server, just start conversation
            let userToStartWith = withContactPair.exactMatches(withUsers: users).first ?? users[0]
            
            self.canStartConversation(withUser: userToStartWith) { canStart, exception in
                if canStart {
                    completion(.startConversation(withContactPair))
                } else {
                    completion(.displayError(exception ?? Exception(metadata: [#file, #function, #line])))
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Data Procesing */
    
    private func canStartConversation(withUser: User,
                                      completion: @escaping(_ canStart: Bool,
                                                            _ exception: Exception?) -> Void) {
        guard withUser.identifier != RuntimeStorage.currentUser!.identifier else {
            completion(false, Exception("Cannot start a conversation with yourself.",
                                        extraParams: ["CurrentUser.Identifier": RuntimeStorage.currentUser!.identifier!,
                                                      "CurrentUserID": RuntimeStorage.currentUserID!],
                                        metadata: [#file, #function, #line]))
            return
        }
        
        RuntimeStorage.currentUser!.deSerializeConversations(completion: { (returnedConversations,
                                                                            exception) in
            guard let conversations = returnedConversations else {
                completion(false, exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            guard !conversations.contains(where: { $0.participants.contains(where: { $0.userID == withUser.identifier }) }) else {
                completion(false, Exception("Conversation with this user already exists.",
                                            extraParams: ["UserID": withUser.identifier!],
                                            metadata: [#file, #function, #line]))
                return
            }
            
            completion(true, nil)
        })
    }
    
    public func createConversation(withUser: User,
                                   completion: @escaping(_ exception: Exception?) -> Void) {
        ConversationSerializer.shared.createConversation(initialMessageIdentifier: "!",
                                                         participants: [RuntimeStorage.currentUserID!,
                                                                        withUser.identifier]) { (returnedConversation, exception) in
            
            guard let conversation = returnedConversation else {
                completion(exception ?? Exception(metadata: [#file, #function, #line]))
                return
            }
            
            conversation.setOtherUser { (exception) in
                guard exception == nil else {
                    completion(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                guard RuntimeStorage.currentUser!.openConversations == nil else {
                    RuntimeStorage.currentUser!.openConversations!.append(conversation)
                    return
                }
                
                RuntimeStorage.currentUser!.deSerializeConversations { (returnedConversations,
                                                                        exception) in
                    guard let updatedConversations = returnedConversations else {
                        completion(exception ?? Exception(metadata: [#file, #function, #line]))
                        return
                    }
                    
                    RuntimeStorage.currentUser!.openConversations = updatedConversations
                    RuntimeStorage.store(RuntimeStorage.currentUser!.openConversations!, as: .conversations)
                    
                    ConversationArchiver.addToArchive(conversation)
                    
                    completion(nil)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - User Prompting */
    
    private func presentSelectNumberActionSheet(contactPair: ContactPair,
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
            
            let cancelAction = UIAlertAction(title: cancel.output, style: .cancel)
            alertController.addAction(cancelAction)
            
            Core.ui.politelyPresent(viewController: alertController)
        }
    }
}
