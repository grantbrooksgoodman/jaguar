//
//  Message.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

public class Message {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Dates
    public var readDate: Date?
    public var sentDate: Date
    
    //Strings
    public var identifier: String!
    public var fromAccountIdentifier: String!
    
    //Other Declarations
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
    
    ///Serializes the **Message's** metadata.
    public func serialize() -> [String: Any] {
        var dataBundle: [String: Any] = [:]
        
        dataBundle["fromAccount"] = fromAccountIdentifier
        dataBundle["languagePair"] = languagePair.asString()
        dataBundle["translationReference"] = translation.serialize().key
        dataBundle["readDate"] = (readDate == nil ? "!" : masterDateFormatter.string(from: readDate!))
        dataBundle["sentDate"] = masterDateFormatter.string(from: sentDate)
        
        return dataBundle
    }
}
