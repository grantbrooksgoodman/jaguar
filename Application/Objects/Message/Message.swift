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

public class Message: Codable, Equatable {
    
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
    
    public var hasAudioComponent: Bool!
    public var audioComponent: AudioMessageReference?
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(identifier: String,
                fromAccountIdentifier: String,
                languagePair: LanguagePair,
                translation: Translation,
                readDate: Date?,
                sentDate: Date,
                hasAudioComponent: Bool,
                audioComponent: AudioMessageReference? = nil) {
        self.identifier = identifier
        self.fromAccountIdentifier = fromAccountIdentifier
        self.languagePair = languagePair
        self.translation = translation
        self.readDate = readDate
        self.sentDate = sentDate
        self.hasAudioComponent = hasAudioComponent
        self.audioComponent = audioComponent
    }
    
    //==================================================//
    
    /* MARK: - Equatable Compliance Method */
    
    public static func == (left: Message, right: Message) -> Bool {
        let identifiersMatch = left.identifier == right.identifier
        let fromAccountIdsMatch = left.fromAccountIdentifier == right.fromAccountIdentifier
        let languagePairsMatch = left.languagePair.asString() == right.languagePair.asString()
        let translationsMatch = left.translation == right.translation
        let readDatesMatch = left.readDate == right.readDate
        let sentDatesMatch = left.sentDate == right.sentDate
        let displayingAlternatesMatch = left.isDisplayingAlternate == right.isDisplayingAlternate
        let audioComponentsMatch = left.hasAudioComponent == right.hasAudioComponent
        
        return identifiersMatch && fromAccountIdsMatch && languagePairsMatch && translationsMatch && readDatesMatch && sentDatesMatch && displayingAlternatesMatch && audioComponentsMatch
    }
    
    //==================================================//
    
    /* MARK: - Serialization */
    
    public func hashSerialized() -> [String] {
        var hashFactors = [String]()
        
        if let readDate {
            hashFactors.append(Core.secondaryDateFormatter.string(from: readDate))
        }
        
        hashFactors.append(Core.secondaryDateFormatter.string(from: sentDate))
        hashFactors.append(identifier)
        hashFactors.append(fromAccountIdentifier)
        hashFactors.append(languagePair.asString())
        hashFactors.append(hasAudioComponent.description)
        
        return hashFactors
    }
    
    /// Serializes the **Message's** metadata.
    public func serialize() -> [String: Any] {
        var data: [String: Any] = [:]
        
        data["fromAccount"] = fromAccountIdentifier
        data["languagePair"] = languagePair.asString()
        data["translationReference"] = translation.serialize().key
        data["readDate"] = (readDate == nil ? "!" : Core.masterDateFormatter!.string(from: readDate!))
        data["sentDate"] = Core.secondaryDateFormatter!.string(from: sentDate)
        data["hasAudioComponent"] = hasAudioComponent ? "true" : "false"
        
        return data
    }
    
    //==================================================//
    
    /* MARK: - Updating Methods */
    
    public func updateLanguagePair(_ newPair: LanguagePair,
                                   completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/messages/"
        GeneralSerializer.setValue(newPair.asString(),
                                   forKey: "\(pathPrefix)\(identifier!)/languagePair") { exception in
            guard let exception else {
                completion(nil)
                return
            }
            
            completion(exception)
        }
    }
    
    public func updateReadDate(completion: @escaping (_ exception: Exception?) -> Void = { _ in }) {
        readDate = Date()
        
        let pathPrefix = "/\(GeneralSerializer.environment.shortString)/messages/"
        GeneralSerializer.setValue(Core.secondaryDateFormatter!.string(from: readDate!),
                                   forKey: "\(pathPrefix)\(identifier!)/readDate") { exception in
            guard let exception else {
                completion(nil)
                return
            }
            
            completion(exception)
        }
    }
}

