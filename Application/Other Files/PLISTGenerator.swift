//
//  PLISTGenerator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

/* Third-party Frameworks */
import Translator

public struct PLISTGenerator {
    public static func createPLIST(from dictionary: [String: String]) {
        let fileManager = FileManager.default
        
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let path = documentDirectory.appending("/document.plist")
        
        if !fileManager.fileExists(atPath: path) {
            NSDictionary(dictionary: dictionary).write(toFile: path, atomically: true)
            
            Logger.log("File created at path:\n\(path)",
                       metadata: [#file, #function, #line])
        } else {
            Logger.log("File already exists!",
                       metadata: [#file, #function, #line])
        }
    }
    
    public static func translate(text: String,
                                 toLanguages: [String]) {
        var translations = [String: String]()
        
        let dispatchGroup = DispatchGroup()
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        for (index, languageCode) in toLanguages.enumerated() {
            dispatchGroup.enter()
            
            FirebaseTranslator.shared.translate(TranslationInput(text),
                                                with: LanguagePair(from: "en",
                                                                   to: languageCode),
                                                using: .random) { (returnedTranslation, errorDescriptor) in
                dispatchGroup.leave()
                
                guard let translation = returnedTranslation else {
                    Logger.log(errorDescriptor ?? "An unknown error occurred.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                Logger.logToStream("Translated item \(index + 1) of \(toLanguages.count).",
                                   line: #line)
                
                translations[languageCode] = translation.output
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            Logger.closeStream(message: "All strings should be translated; complete.",
                               onLine: #line)
            self.createPLIST(from: translations)
        }
    }
}
