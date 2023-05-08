//
//  Message+MessageExtensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import Translator

public extension Message {
    
    // MARK: Properties
    
    var backgroundColor: UIColor {
        let isFromCurrentUser = fromAccountIdentifier == RuntimeStorage.currentUserID
        
        guard let currentUser = RuntimeStorage.currentUser,
              let otherUser = RuntimeStorage.coordinator?.conversation.wrappedValue.otherUser,
              translation.input.value() == translation.output,
              audioComponent == nil,
              sender.senderId == RuntimeStorage.currentUserID,
              currentUser.languageCode != otherUser.languageCode,
              RecognitionService.shouldMarkUntranslated(translation.output,
                                                        for: translation.languagePair) else {
            return isFromCurrentUser ? .senderMessageBubbleColor : .receiverMessageBubbleColor
        }
        
        return .untranslatedMessageBubbleColor
    }
    
    var hash: String {
        do {
            let encoder = JSONEncoder()
            let encodedMessage = try! encoder.encode(self.hashSerialized())
            
            return encodedMessage.compressedHash
        }
    }
    
    var localAudioFilePaths: (directoryPathString: String,
                              inputPathString: String,
                              inputPathURL: URL,
                              outputPathString: String,
                              outputPathURL: URL)? {
        guard hasAudioComponent else { return nil }
        
        let fileManager = FileManager.default
        
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/audioMessages/"
        let subPath = "\(translation.languagePair.asString())/\(translation.serialize().key)"
        let fullPath = "\(pathPrefix)\(subPath)"
        
        let inputFilePath = "\(fullPath)/\(identifier!).m4a"
        var outputFilePath = "\(fullPath)/output.m4a"
        if translation.languagePair.from == translation.languagePair.to {
            outputFilePath = inputFilePath
        }
        
        let inputFileURL = fileManager.documentsDirectoryURL.appendingPathComponent(inputFilePath)
        let outputFileURL = fileManager.documentsDirectoryURL.appendingPathComponent(outputFilePath)
        
        return (directoryPathString: fullPath,
                inputPathString: inputFilePath,
                inputPathURL: inputFileURL,
                outputPathString: outputFilePath,
                outputPathURL: outputFileURL)
    }
    
    // MARK: Methods
    
    static func empty() -> Message {
        return Message(identifier: "",
                       fromAccountIdentifier: "",
                       languagePair: LanguagePair(from: "",
                                                  to: ""),
                       translation: Translation(input: TranslationInput(""),
                                                output: "",
                                                languagePair: LanguagePair(from: "",
                                                                           to: "")),
                       readDate: nil,
                       sentDate: Date(timeIntervalSince1970: 0),
                       hasAudioComponent: false)
    }
}
