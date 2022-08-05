//
//  ConversationArchiver.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct ConversationArchiver {
    
    //==================================================//
    
    /* MARK: - Addition/Retrieval Functions */
    
    public static func addToArchive(_ conversation: Conversation) {
        initializeArchive()
        conversationArchive.append(conversation)
        
        Logger.log("Added conversation to local archive.",
                   verbose: true,
                   metadata: [#file, #function, #line])
    }
    
    public static func addToArchive(_ conversations: [Conversation]) {
        initializeArchive()
        
        conversationArchive.removeAll(where: { $0.identifier.isAny(in: conversations.identifiers()) })
        conversationArchive.append(contentsOf: conversations)
        
        Logger.log("Added conversations to local archive.",
                   verbose: true,
                   metadata: [#file, #function, #line])
    }
    
    public static func getFromArchive(_ identifier: String) -> Conversation? {
        initializeArchive()
        
        let conversations = conversationArchive.filter({ $0.identifier == identifier })
        
        if conversations.first != nil {
            Logger.log("Found conversation in local archive.",
                       verbose: true,
                       metadata: [#file, #function, #line])
        }
        
        return conversations.first
    }
    
    //==================================================//
    
    /* MARK: - Getter/Setter Functions */
    
    public static func getArchive(completion: @escaping (_ returnedTuple: (conversations: [Conversation], userID: String)?,
                                                         _ errorDescriptor: String?) -> Void) {
        guard let conversationData = UserDefaults.standard.object(forKey: "conversationArchive") as? Data,
              let userID = UserDefaults.standard.object(forKey: "conversationArchiveUserID") as? String else {
            completion(nil, "Couldn't decode conversation archive. May be empty.")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedConversations = try decoder.decode([Conversation].self,
                                                          from: conversationData)
            
            completion((conversations: decodedConversations, userID: userID), nil)
            return
        } catch let error {
            Logger.log(Logger.errorInfo(error),
                       metadata: [#file, #function, #line])
            
            completion(nil, Logger.errorInfo(error))
        }
    }
    
    public static func setArchive(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        do {
            let encoder = JSONEncoder()
            let encodedConversations = try encoder.encode(conversationArchive)
            
            UserDefaults.standard.setValue(encodedConversations, forKey: "conversationArchive")
            UserDefaults.standard.setValue(currentUserID, forKey: "conversationArchiveUserID")
            completion(nil)
        } catch let error {
            Logger.log(Logger.errorInfo(error),
                       metadata: [#file, #function, #line])
            
            completion(Logger.errorInfo(error))
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private static func initializeArchive() {
        getArchive { (returnedTuple,
                      errorDescriptor) in
            guard let tuple = returnedTuple else {
                return
            }
            
            conversationArchive = tuple.conversations
        }
    }
}
