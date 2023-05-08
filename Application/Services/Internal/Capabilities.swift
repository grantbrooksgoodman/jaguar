//
//  Capabilities.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 05/03/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFoundation
import Foundation
import Speech

public struct Capabilities {
    
    //==================================================//
    
    /* MARK: - Methods */
    
    public static func textToSpeechSupported(for outputLanguage: String) -> Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        guard voices.contains(where: { $0.language.lowercased().hasPrefix(outputLanguage.lowercased()) }) else { return false }
        
        return true
    }
    
    public static func transcriptionSupported(for inputLanguage: String) -> Bool {
        var supported = [String]()
        for locale in SFSpeechRecognizer.supportedLocales() {
            var languageCode: String?
            if #available(iOS 16.0, *) {
                languageCode = locale.language.languageCode?.identifier
            } else {
                languageCode = locale.languageCode
            }
            guard let languageCode else { continue }
            supported.append(languageCode.lowercased())
        }
        
        return supported.contains(where: { $0.hasPrefix(inputLanguage.lowercased()) })
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - User */
public extension User {
    /* Properties */
    
    /* To SEND messages, the only thing needed is transcription.
     TTS only comes into play when working with translations */
    var canSendAudioMessages: Bool { get { Capabilities.transcriptionSupported(for: languageCode) } }
    
    /* Methods */
    func canSendAudioMessages(to user: User) -> Bool {
        return canSendAudioMessages && Capabilities.textToSpeechSupported(for: user.languageCode)
    }
}
