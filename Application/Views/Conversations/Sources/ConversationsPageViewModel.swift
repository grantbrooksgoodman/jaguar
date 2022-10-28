//
//  ConversationsPageViewModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import Firebase
import Translator

public class ConversationsPageViewModel: ObservableObject {
    
    //==================================================//
    
    /* MARK: - Enums */
    
    public enum State {
        case idle
        case loading
        case failed(Exception)
        case loaded(translations: [String: Translator.Translation],
                    conversations: [Conversation])
    }
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public let dataModel = ConversationsPageViewDataModel()
    public let inputs = ["messages": Translator.TranslationInput("Messages")]
    
    @Published private(set) var state = State.idle
    private var translations: [String: Translator.Translation]!
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public func load() {
        state = .loading
        
        ContactService.clearCache()
        
        UserSerializer.shared.getUser(withIdentifier: RuntimeStorage.currentUserID!) { (returnedUser,
                                                                                        exception) in
            guard let user = returnedUser else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                return
            }
            
            UserDefaults.standard.setValue(RuntimeStorage.currentUserID!, forKey: "currentUserID")
            
            RuntimeStorage.store(user, as: .currentUser)
            
            RuntimeStorage.store(user.languageCode!, as: .languageCode)
            AKCore.shared.setLanguageCode(user.languageCode)
            
            //            RuntimeStorage.store("en", as: .languageCode)
            //            AKCore.shared.setLanguageCode("en")
            
            user.deSerializeConversations { (returnedConversations,
                                             exception) in
                guard let conversations = returnedConversations else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                               with: .errorAlert)
                    return
                }
                
                //                conversations.forEach { conversation in
                //                    self.setUpObserver(for: conversation)
                //                }
                
                self.translateAndLoad(conversations: conversations)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func conversationsToUse(for: [Conversation]) -> [Conversation] {
        guard let conversations = RuntimeStorage.conversations,
              conversations.isEmpty else {
            return `for`.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
        }
        
        guard conversations.isEmpty else {
            return conversations.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
        }
        
        return `for`.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
    }
    
    public func deleteConversation(at offsets: IndexSet) {
        let confirmationAlert = AKConfirmationAlert(message: "Are you sure you'd like to delete this conversation?",
                                                    confirmationStyle: .destructive)
        
        confirmationAlert.present { (actionID) in
            
            guard actionID == 1 else {
                return
            }
            
            guard let offset = offsets.first,
                  offset < RuntimeStorage.conversations!.count else {
                return
            }
            
            let identifier = RuntimeStorage.conversations!.reversed()[offset].identifier.key!
            ConversationSerializer.shared.deleteConversation(withIdentifier: identifier) { (exception) in
                if let error = exception {
                    Logger.log(error,
                               with: .errorAlert)
                }
                
                RuntimeStorage.currentUser!.deSerializeConversations { (returnedConversations,
                                                                        exception) in
                    guard let updatedConversations = returnedConversations else {
                        Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                                   with: .errorAlert)
                        return
                    }
                    
                    RuntimeStorage.store(updatedConversations, as: .conversations)
                    self.load()
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - User Prompting */
    
    private func presentNoUserAlert(exception: Exception? = nil) {
        let noUserString = "No user exists with the provided phone number."
        
        Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                   with: exception?.descriptor == noUserString ? .none : .errorAlert)
        
        if exception?.descriptor == noUserString {
            let alert = AKAlert(message: "\(noUserString)\n\nWould you like to send them an invite to sign up?",
                                actions: [AKAction(title: "Send Invite",
                                                   style: .preferred)])
            alert.present { (actionID) in
                if actionID != -1 {
                    print("wants to invite")
                }
            }
        }
    }
    
    public func presentPromptMethodAlert(completion: @escaping(_ showContactPopover: Bool?) -> Void) {
        let actions = [AKAction(title: "Enter Number",
                                style: .default),
                       AKAction(title: "Select Contact",
                                style: .preferred)]
        
        let alert = AKAlert(message: "Would you like to enter a number or select a contact?",
                            actions: actions)
        
        alert.present { actionID in
            switch actionID {
            case actions[0].identifier:
                self.presentPromptPhoneNumberAlert()
                completion(false)
            case actions[1].identifier:
                RuntimeStorage.remove(.selectedContactPair)
                completion(true)
            default:
                completion(nil)
            }
        }
    }
    
    private func presentPromptPhoneNumberAlert() {
        let alert = UIAlertController(title: "Enter the number below:",
                                      message: "",
                                      preferredStyle: .alert)
        alert.addTextField { textField in
            textField.clearButtonMode = .unlessEditing
            textField.keyboardType = .phonePad
            textField.placeholder = "+1 (555) 555-5555"
            textField.textAlignment = .center
        }
        
        let okAction = UIAlertAction(title: "OK",
                                     style: .default) { _ in
            self.routeNavigation(withNumber: alert.textFields![0].text!.digits)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .cancel)
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: alert.textFields![0], queue: .main) { _ in
            let textField = alert.textFields![0]
            
            textField.text = textField.text?.formattedPhoneNumber(region: "US")
        }
        
        Core.ui.politelyPresent(viewController: alert)
    }
    
    private func presentSelectNumberActionSheet(contactPair: ContactPair,
                                                users: [User]) {
        let originalPrompt = "Which of \(contactPair.contact.firstName)'s numbers would you like to use to start this conversation?"
        
        let messageInput = Translator.TranslationInput(originalPrompt, alternate: "Select which number you would like to use to start this conversation.")
        
        FirebaseTranslator.shared.getTranslations(for: [TranslationInput("Select Number"),
                                                        messageInput,
                                                        TranslationInput("Cancel")],
                                                  languagePair: LanguagePair(from: "en", to: RuntimeStorage.languageCode!)) { returnedTranslations, exception in
            guard let translations = returnedTranslations else {
                if let error = exception {
                    Logger.log(error)
                }
                
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
                    RuntimeStorage.store(ContactPair(contact: contactPair.contact,
                                                     users: [user]),
                                         as: .selectedContactPair)
                    self.routeNavigationWithSelectedContactPair()
                }
                
                alertController.addAction(userAction)
            }
            
            let cancelAction = UIAlertAction(title: cancel.output, style: .cancel)
            alertController.addAction(cancelAction)
            
            Core.ui.politelyPresent(viewController: alertController)
        }
    }
    
    private func presentSelectCallingCodeActionSheet(contactPair: ContactPair,
                                                     users: [User]) {
        let originalPrompt = "It appears there may be multiple users with \(contactPair.contact.firstName) \(contactPair.contact.lastName)'s phone number. To continue, please select the calling code of \(contactPair.contact.firstName)'s number."
        
        let messageInput = Translator.TranslationInput(originalPrompt, alternate: "It appears there may be multiple users with this phone number. To continue, please select the appropriate calling code.")
        
        FirebaseTranslator.shared.getTranslations(for: [TranslationInput("Select Region"),
                                                        messageInput,
                                                        TranslationInput("Cancel")],
                                                  languagePair: LanguagePair(from: "en", to: RuntimeStorage.languageCode!)) { returnedTranslations, exception in
            guard let translations = returnedTranslations else {
                if let error = exception {
                    Logger.log(error)
                }
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
                    RuntimeStorage.store(ContactPair(contact: contactPair.contact,
                                                     users: [user]),
                                         as: .selectedContactPair)
                    self.routeNavigationWithSelectedContactPair()
                }
                
                alertController.addAction(userAction)
            }
            
            let cancelAction = UIAlertAction(title: cancel.output, style: .cancel)
            alertController.addAction(cancelAction)
            
            Core.ui.politelyPresent(viewController: alertController)
        }
    }
    
    //==================================================//
    
    /* MARK: - Navigation Routing */
    
    private func handleDuplicates(contactPair: ContactPair,
                                  users: [User]) {
        dataModel.handleDuplicates(contactPair: contactPair,
                                   users: users) { result in
            switch result {
            case .displayError(let exception):
                Logger.log(exception,
                           with: .errorAlert)
            case .handleDuplicates(let contactPair, let users):
                self.handleDuplicates(contactPair: contactPair, users: users)
            case .chooseCallingCode(let contactPair, let users):
                self.presentSelectCallingCodeActionSheet(contactPair: contactPair, users: users)
            case .selectNumber(let contactPair, let users):
                self.presentSelectNumberActionSheet(contactPair: contactPair, users: users)
            case .startConversation(_):
                self.routeNavigationWithSelectedContactPair()
            }
        }
    }
    
    private func routeNavigation(withNumber: String) {
        UserSerializer.shared.findUsers(forPhoneNumbers: [withNumber]) { returnedUsers, exception in
            guard let users = returnedUsers else {
                self.presentNoUserAlert(exception: exception)
                return
            }
            
            let contactPair = ContactPair(contact: Contact(firstName: "",
                                                           lastName: "",
                                                           phoneNumbers: []),
                                          users: users)
            
            RuntimeStorage.store(contactPair, as: .selectedContactPair)
            self.routeNavigationWithSelectedContactPair()
        }
    }
    
    public func routeNavigationWithSelectedContactPair() {
        guard let contactPair = RuntimeStorage.selectedContactPair else {
            Logger.log("Contact selection was not processed.",
                       metadata: [#file, #function, #line])
            return
        }
        
        dataModel.routeNavigation(withContactPair: contactPair) { result in
            switch result {
            case .displayError(let exception):
                Logger.log(exception,
                           with: .errorAlert)
            case .handleDuplicates(let contactPair, let users):
                self.handleDuplicates(contactPair: contactPair, users: users)
            case .startConversation(let contactPair):
                guard let users = contactPair.users else {
                    Logger.log("No users for this contact pair.",
                               with: .errorAlert,
                               metadata: [#file, #function, #line])
                    return
                }
                
                self.dataModel.createConversation(withUser: users[0]) { exception in
                    guard exception == nil else {
                        Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                                   with: .errorAlert)
                        return
                    }
                    
                    self.load()
                }
            default:
                Logger.log("Invalid navigation destination!",
                           with: .errorAlert,
                           metadata: [#file, #function, #line])
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Miscellaneous Functions */
    
    private func setUpObserver(for conversation: Conversation) {
        Database.database().reference().child("/allConversations/\(conversation.identifier!.key!)").observe(.childChanged) { (returnedSnapshot) in
            guard returnedSnapshot.key == "messages",
                  let messageIdentifiers = returnedSnapshot.value as? [String],
                  let newMessageID = messageIdentifiers.last else {
                return
            }
            
            self.state = .loading
            
            MessageSerializer.shared.getMessage(withIdentifier: newMessageID) { (returnedMessage,
                                                                                 exception) in
                guard let message = returnedMessage else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                    return
                }
                
                conversation.messages.append(message)
                conversation.messages = conversation.sortedFilteredMessages()
                RuntimeStorage.store(RuntimeStorage.conversations!.unique(), as: .conversations)
                
                self.state = .loaded(translations: self.translations,
                                     conversations: RuntimeStorage.conversations!)
            }
        } withCancel: { (error) in
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
    
    private func translateAndLoad(conversations: [Conversation]) {
        let dataModel = PageViewDataModel(inputs: self.inputs)
        
        dataModel.translateStrings { (returnedTranslations,
                                      returnedException) in
            guard let translations = returnedTranslations else {
                let exception = returnedException ?? Exception(metadata: [#file, #function, #line])
                Logger.log(exception)
                
                self.state = .failed(exception)
                return
            }
            
            self.translations = translations
            self.state = .loaded(translations: translations,
                                 conversations: conversations)
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - Array */
public extension Array where Element == String {
    var duplicates: [String]? {
        let duplicates = Array(Set(filter({ (s: String) in filter({ $0 == s }).count > 1})))
        return duplicates.isEmpty ? nil : duplicates
    }
}
