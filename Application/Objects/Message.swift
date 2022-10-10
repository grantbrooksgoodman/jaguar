//
//  Message.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

/* Third-party Frameworks */
import Translator

public class Message: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Dates
    public var readDate: Date?
    public var sentDate: Date
    
    // Strings
    public var identifier: String!
    public var fromAccountIdentifier: String!
    
    // Other
    public var isDisplayingAlternate = false
    public var languagePair: LanguagePair!
    public var translation: Translation!
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(identifier: String,
                fromAccountIdentifier: String,
                languagePair: LanguagePair,
                translation: Translation,
                readDate: Date?,
                sentDate: Date) {
        self.identifier = identifier
        self.fromAccountIdentifier = fromAccountIdentifier
        self.languagePair = languagePair
        self.translation = translation
        self.readDate = readDate
        self.sentDate = sentDate
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    /// Serializes the **Message's** metadata.
    public func serialize() -> [String: Any] {
        var data: [String: Any] = [:]
        
        data["fromAccount"] = fromAccountIdentifier
        data["languagePair"] = languagePair.asString()
        data["translationReference"] = translation.serialize().key
        data["readDate"] = (readDate == nil ? "!" : Core.masterDateFormatter!.string(from: readDate!))
        data["sentDate"] = Core.secondaryDateFormatter!.string(from: sentDate)
        
        return data
    }
    
    public func updateReadDate(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        readDate = Date()
        
        GeneralSerializer.setValue(onKey: "/allMessages/\(identifier!)/readDate",
                                   withData: Core.secondaryDateFormatter!.string(from: readDate!)) { returnedError in
            guard let error = returnedError else {
                completion(nil)
                return
            }
            
            completion(Logger.errorInfo(error))
        }
    }
}
