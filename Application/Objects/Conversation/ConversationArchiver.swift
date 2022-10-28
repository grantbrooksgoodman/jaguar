//
//  ConversationArchiver.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public enum ConversationArchiver {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) static var conversationArchive = [Conversation]() { didSet { ConversationArchiver.setArchive() } }
    
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
        
        conversationArchive.removeAll(where: { $0.identifier.key.isAny(in: conversations.identifierKeys()) })
        conversationArchive.append(contentsOf: conversations)
        
        Logger.log("Added conversations to local archive.",
                   verbose: true,
                   metadata: [#file, #function, #line])
    }
    
    public static func getFromArchive(_ identifier: ConversationID) -> Conversation? {
        initializeArchive()
        
        return conversationArchive.filter { $0.identifier == identifier }.first
    }
    
    public static func getFromArchive(withKey: String) -> Conversation? {
        initializeArchive()
        
        return conversationArchive.filter({ $0.identifier.key == withKey }).first
    }
    
    //==================================================//
    
    /* MARK: - Getter/Setter Functions */
    
    public static func clearArchive() {
        UserDefaults.standard.setValue(nil, forKey: "conversationArchive")
        UserDefaults.standard.setValue(nil, forKey: "conversationArchiveUserID")
        conversationArchive = []
    }
    
    public static func getArchive(completion: @escaping (_ returnedTuple: (conversations: [Conversation], userID: String)?,
                                                         _ exception: Exception?) -> Void) {
        guard let conversationData = UserDefaults.standard.object(forKey: "conversationArchive") as? Data,
              let userID = UserDefaults.standard.object(forKey: "conversationArchiveUserID") as? String
        else {
            completion(nil, Exception("Couldn't decode conversation archive. May be empty.",
                                      metadata: [#file, #function, #line]))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedConversations = try decoder.decode([Conversation].self,
                                                          from: conversationData)
            setUpStaticArchive((conversations: decodedConversations, userID: userID))
            completion((conversations: decodedConversations, userID: userID), nil)
            return
        } catch {
            Logger.log(Exception(error,
                                 metadata: [#file, #function, #line]))
            
            completion(nil, Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    public static func setArchive(completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        guard let currentUserID = RuntimeStorage.currentUserID else {
            completion(Exception("No current user ID.",
                                 metadata: [#file, #function, #line]))
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let encodedConversations = try encoder.encode(conversationArchive)
            
            UserDefaults.standard.setValue(encodedConversations, forKey: "conversationArchive")
            UserDefaults.standard.setValue(currentUserID, forKey: "conversationArchiveUserID")
            completion(nil)
        } catch {
            Logger.log(Exception(error,
                                 metadata: [#file, #function, #line]))
            
            completion(Exception(error, metadata: [#file, #function, #line]))
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private static func initializeArchive() {
        getArchive { returnedTuple,
            _ in
            guard let tuple = returnedTuple else {
                return
            }
            
            conversationArchive = tuple.conversations
        }
    }
    
    private static func setUpStaticArchive(_ with: (conversations: [Conversation], userID: String)) {
        guard with.userID == RuntimeStorage.currentUserID else {
            Logger.log("Different user ID – nuking conversation archive.",
                       metadata: [#file, #function, #line])
            clearArchive()
            return
        }
        
        conversationArchive = with.conversations.filter { $0.participants.contains(where: { $0.userID == RuntimeStorage.currentUserID! }) }
    }
}
