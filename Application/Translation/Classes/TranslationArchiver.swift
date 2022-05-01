//
//  TranslationInput.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct TranslationArchiver {
    
    //==================================================//
    
    /* MARK: - Addition/Retrieval Functions */
    
    public static func addToArchive(_ translation: Translation) {
        log("Added translation to local archive.",
            verbose: true,
            metadata: [#file, #function, #line])
        
        translationArchive.append(translation)
    }
    
    public static func getFromArchive(_ input: TranslationInput,
                                      languagePair: LanguagePair) -> Translation? {
        let translations = translationArchive.filter({ $0.languagePair.to == languagePair.to })
        let matches = translations.filter({$0.input.value() == input.value()})
        
        if matches.first != nil {
            log("Found translation in local archive.",
                metadata: [#file, #function, #line])
        }
        
        return matches.first
    }
    
    //==================================================//
    
    /* MARK: - Getter/Setter Functions */
    
    public static func getArchive(completion: @escaping (_ translations: [Translation]?,
                                                         _ errorDescriptor: String?) -> Void) {
        guard let translationData = UserDefaults.standard.object(forKey: "translationArchive") as? Data else {
            completion(nil, "Couldn't decode translation archive. May be empty.")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedTranslations = try decoder.decode([Translation].self,
                                                         from: translationData)
            
            completion(decodedTranslations, nil)
            return
        } catch let error {
            log(errorInfo(error),
                metadata: [#file, #function, #line])
            
            completion(nil, errorInfo(error))
        }
    }
    
    public static func setArchive(completion: @escaping (_ errorDescriptor: String?) -> Void = { _ in }) {
        do {
            let encoder = JSONEncoder()
            let encodedTranslations = try encoder.encode(translationArchive)
            
            UserDefaults.standard.setValue(encodedTranslations, forKey: "translationArchive")
            completion(nil)
        } catch let error {
            log(errorInfo(error),
                metadata: [#file, #function, #line])
            
            completion(errorInfo(error))
        }
    }
}
