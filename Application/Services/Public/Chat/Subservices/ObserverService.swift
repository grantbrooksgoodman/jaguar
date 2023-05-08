//
//  ObserverService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import FirebaseDatabase

public class ObserverService: ChatService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var serviceType: ChatServiceType = .observer
    
    private var CURRENT_MESSAGE_SLICE: [Message]!
    private var GLOBAL_CONVERSATION: Conversation!
    
    //==================================================//
    
    /* MARK: - Constructor & Initialization Methods */
    
    public init() throws {
        guard syncDependencies() else { throw ObserverServiceError.failedToRetrieveDependencies }
    }
    
    @discardableResult
    private func syncDependencies() -> Bool {
        guard let currentMessageSlice = RuntimeStorage.currentMessageSlice,
              let globalConversation = RuntimeStorage.globalConversation else { return false }
        
        CURRENT_MESSAGE_SLICE = currentMessageSlice
        GLOBAL_CONVERSATION = globalConversation
        
        return true
    }
    
    //==================================================//
    
    /* MARK: - Observer Methods */
    
    public func setUpNewMessageObserver() {
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/conversations/"
        Database.database().reference().child("\(pathPrefix)\(GLOBAL_CONVERSATION.identifier!.key!)/messages").observe(.childAdded) { snapshot in
            self.syncDependencies()
            
            guard let identifier = snapshot.value as? String,
                  !self.GLOBAL_CONVERSATION.messages.contains(where: { $0.identifier == identifier }) else { return }
            
            guard RuntimeStorage.coordinator?.conversation.wrappedValue.identifier.key == self.GLOBAL_CONVERSATION.identifier.key else {
                RuntimeStorage.store(true, as: .receivedNotification)
                return
            }
            
            MessageSerializer.shared.getMessage(withIdentifier: identifier) { (returnedMessage,
                                                                               exception) in
                guard let message = returnedMessage else {
                    if let error = exception,
                       error.descriptor != "Null/first message processed." {
                        // #warning("Consistently getting no archive for language pair error on some accounts.")
                        Logger.log(error)
                    }
                    
                    return
                }
                
                guard message.fromAccountIdentifier != RuntimeStorage.currentUserID else { return }
                
                print("Appending message with ID: \(message.identifier!)")
                self.GLOBAL_CONVERSATION.messages.append(message)
                self.GLOBAL_CONVERSATION.messages = self.GLOBAL_CONVERSATION.messages.filteredAndSorted
                
                self.GLOBAL_CONVERSATION.identifier.hash = self.GLOBAL_CONVERSATION.hash
                
                RuntimeStorage.store(self.GLOBAL_CONVERSATION!, as: .globalConversation)
                
                var messageSlice = self.CURRENT_MESSAGE_SLICE!
                messageSlice.append(message)
                RuntimeStorage.store(messageSlice.filteredAndSorted, as: .currentMessageSlice)
                
                print("Adding to archive \(self.GLOBAL_CONVERSATION.identifier.key!) | \(self.GLOBAL_CONVERSATION.identifier.hash!)")
                ConversationArchiver.addToArchive(self.GLOBAL_CONVERSATION)
                
                RuntimeStorage.store(true, as: .shouldReloadData)
            }
        } withCancel: { (error) in
            Logger.log(error,
                       metadata: [#file, #function, #line])
        }
    }
    
    public func setUpReadDateObserver() {
        // #warning("Such a broad observer isn't great for efficiency, but it may be the only way to do this with the current database scheme.") // correlate read date with last active date
        Database.database().reference().child(GeneralSerializer.environment.shortString).child("/messages").observe(.childChanged) { returnedSnapshot, _ in
            self.syncDependencies()
            
            guard let lastMessage = self.GLOBAL_CONVERSATION.messages.filteredAndSorted.last else {
                let exception = Exception("Couldn't get last message.",
                                          extraParams: ["UnsortedMessageCount": self.GLOBAL_CONVERSATION.messages.count,
                                                        "SortedMessageCount": self.GLOBAL_CONVERSATION.messages.filteredAndSorted.count],
                                          metadata: [#file, #function, #line])
                Logger.log(exception)
                return
            }
            
            guard let snapshot = returnedSnapshot.value as? NSDictionary,
                  let data = snapshot as? [String: Any] else {
                Logger.log("Couldn't unwrap snapshot.",
                           metadata: [#file, #function, #line])
                return
            }
            
            guard returnedSnapshot.key == lastMessage.identifier else { return }
            
            guard let readDateString = data["readDate"] as? String,
                  let readDate = Core.secondaryDateFormatter!.date(from: readDateString) else {
                Logger.log("Couldn't deserialize «readDate».",
                           metadata: [#file, #function, #line])
                return
            }
            
            lastMessage.readDate = readDate
            RuntimeStorage.store(true, as: .shouldReloadData)
        } withCancel: { (returnedError) in
            Logger.log(returnedError,
                       metadata: [#file, #function, #line])
        }
    }
    
    public func setUpTypingIndicatorObserver() {
        syncDependencies()
        
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/conversations/"
        Database.database().reference().child("\(pathPrefix)\(GLOBAL_CONVERSATION.identifier!.key!)/participants").observe(.childChanged) { (returnedSnapshot) in
            guard let updatedTyper = returnedSnapshot.value as? String,
                  updatedTyper.components(separatedBy: " | ")[0] != RuntimeStorage.currentUserID else { return }
            
            RuntimeStorage.store(updatedTyper.components(separatedBy: " | ")[2] == "true",
                                 as: .typingIndicator)
        } withCancel: { (returnedError) in
            Logger.log(returnedError,
                       metadata: [#file, #function, #line])
        }
    }
}

public enum ObserverServiceError: Error {
    case failedToRetrieveDependencies
}
