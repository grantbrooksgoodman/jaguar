//
//  TranslationSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit

/* Third-party Frameworks */
import Translator

public struct TranslationSerializer {
    
    //==================================================//
    
    /* MARK: - Uploading Functions */
    
    public static func uploadTranslation(_ translation: Translation,
                                         completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        let languagePair = translation.languagePair
        let serializedTranslation = translation.serialize()
        let dictionary = [serializedTranslation.key: serializedTranslation.value]
        
        GeneralSerializer.updateValue(onKey: "allTranslations/\(languagePair.asString())",
                                      withData: dictionary) { (returnedError) in
            guard let error = returnedError else {
                Logger.log("Successfully uploaded translation.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                
                return
            }
            
            Logger.log("Couldn't upload translation.\n\(Logger.errorInfo(error))",
                       verbose: true,
                       metadata: [#file, #function, #line])
            
            completion(Logger.errorInfo(error))
        }
    }
    
    public static func uploadTranslations(_ translations: [Translation],
                                          completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        let languagePairs = translations.languagePairs()
        var finalErrorDescriptor = ""
        
        let dispatchGroup = DispatchGroup()
        
        for pair in languagePairs {
            dispatchGroup.enter()
            
            uploadTranslations(translations.where(languagePair: pair),
                               for: pair) { (errorDescriptor) in
                if let error = errorDescriptor {
                    finalErrorDescriptor += "\(error)\n"
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(finalErrorDescriptor == "" ? nil : finalErrorDescriptor.trimmingTrailingNewlines)
        }
    }
    
    //==================================================//
    
    /* MARK: - Downloading Functions */
    
    public static func downloadTranslations(completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        GeneralSerializer.getValues(atPath: "/allTranslations/en-\(languageCode)") { (returnedValues, errorDescriptor) in
            guard let values = returnedValues as? [String: String] else {
                let error = errorDescriptor ?? "No online translation archive for this language pair."
                
                if languageCode != "en" {
                    Logger.log(error,
                               metadata: [#file, #function, #line])
                }
                
                completion(error)
                return
            }
            
            guard let decodedValues = values.hashDecoded() else {
                Logger.log("Unable to decode values.",
                           metadata: [#file, #function, #line])
                completion("Unable to decode values.")
                return
            }
            
            Logger.log("Successfully downloaded translation archive.",
                       verbose: true,
                       metadata: [#file, #function, #line])
            
            let languagePair = LanguagePair(from: "en",
                                            to: languageCode)
            
            for key in decodedValues.keys {
                let input = TranslationInput(key)
                let translation = Translation(input: input,
                                              output: decodedValues[key]!,
                                              languagePair: languagePair)
                
                TranslationArchiver.addToArchive(translation)
            }
        }
    }
    
    public static func findTranslation(withReference: String,
                                       languagePair: LanguagePair,
                                       completion: @escaping(_ returnedTranslation: Translation?,
                                                             _ errorDescriptor: String?) -> Void) {
        let path = "/allTranslations/\(languagePair.asString())"
        
        GeneralSerializer.getValues(atPath: "\(path)/\(withReference)") { (returnedValues,
                                                                           errorDescriptor) in
            guard let value = returnedValues as? String else {
                if returnedValues as? NSNull != nil {
                    completion(nil, "No translations for language pair '\(languagePair.asString())'.")
                } else {
                    let error = errorDescriptor ?? "An unknown error occurred."
                    
                    Logger.log(error,
                               metadata: [#file, #function, #line])
                    completion(nil, error)
                }
                
                return
            }
            
            guard let decodedInput = value.decoded(getInput: true),
                  let decodedOutput = value.decoded(getInput: false) else {
                completion(nil, "Failed to decode translation.")
                return
            }
            
            let translation = Translation(input: TranslationInput(decodedInput),
                                          output: decodedOutput,
                                          languagePair: languagePair)
            
            completion(translation, nil)
        }
    }
    
    public static func findTranslation(for input: TranslationInput,
                                       languagePair: LanguagePair,
                                       completion: @escaping(_ returnedString: String?,
                                                             _ errorDescriptor: String?) -> Void) {
        let path = "/allTranslations/\(languagePair.asString())"
        
        GeneralSerializer.getValues(atPath: "\(path)/\(input.value().compressedHash)") { (returnedValues, errorDescriptor) in
            guard let value = returnedValues as? String else {
                let error = errorDescriptor ?? "No uploaded translation exists."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                completion(nil, error)
                return
            }
            
            guard let decoded = value.decoded(getInput: false) else {
                completion(nil, "Failed to decode translation.")
                return
            }
            
            completion(decoded, nil)
        }
    }
    
    public static func findTranslations(_ for: [TranslationInput],
                                        languagePair: LanguagePair,
                                        completion: @escaping(_ returnedStrings: [String: String]?) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var translationDictionary = [String: String]()
        var didError = false
        
        for input in `for` {
            dispatchGroup.enter()
            
            findTranslation(for: input,
                            languagePair: languagePair) { (returnedString, errorDescriptor) in
                if let translatedString = returnedString {
                    translationDictionary[input.value()] = translatedString
                } else if errorDescriptor != nil {
                    translationDictionary[input.value()] = "!"
                    didError = true
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if translationDictionary.keys.count == `for`.count {
                if didError && Logger.exposureLevel == .verbose {
                    Logger.log("At least one translation could not be found.",
                               metadata: [#file, #function, #line])
                }
                
                if Array(translationDictionary.values).filter({$0 != "!"}).count == 0 {
                    completion(nil)
                } else {
                    completion(translationDictionary)
                }
            } else {
                Logger.log("Mismatched translation input/output.",
                           with: .fatalAlert,
                           metadata: [#file, #function, #line])
                completion(nil)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Removal Functions */
    
    public static func removeTranslation(for input: TranslationInput,
                                         languagePair: LanguagePair,
                                         completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        GeneralSerializer.updateValue(onKey: "/allTranslations/\(languagePair.asString())",
                                      withData: [input.value().compressedHash: NSNull()]) { (returnedError) in
            guard let error = returnedError else {
                Logger.log("Successfully removed translation.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                return
            }
            
            Logger.log("Couldn't remove translation.\n\(Logger.errorInfo(error))",
                       verbose: true,
                       metadata: [#file, #function, #line])
            
            completion(Logger.errorInfo(error))
        }
    }
    
    public static func removeTranslations(for inputs: [TranslationInput],
                                          languagePair: LanguagePair,
                                          completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        var nulledDictionary = [String: Any]()
        for input in inputs {
            nulledDictionary[input.value()] = NSNull()
        }
        
        GeneralSerializer.updateValue(onKey: "/allTranslations/\(languagePair.asString())",
                                      withData: nulledDictionary) { (returnedError) in
            guard let error = returnedError else {
                Logger.log("Successfully removed translations.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                
                return
            }
            
            Logger.log("Couldn't remove translations.\n\(Logger.errorInfo(error))",
                       verbose: true,
                       metadata: [#file, #function, #line])
            
            completion(Logger.errorInfo(error))
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private static func uploadTranslations(_ translations: [Translation],
                                           for languagePair: LanguagePair,
                                           completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        guard translations.homogeneousLanguagePairs() else {
            completion("Translations are not all from the same language!")
            return
        }
        
        var dictionary = [String: String]()
        
        for translation in translations {
            let serialized = translation.serialize()
            
            dictionary[serialized.key] = serialized.value
        }
        
        GeneralSerializer.updateValue(onKey: "/allTranslations/\(languagePair.asString())",
                                      withData: dictionary) { (returnedError) in
            guard let error = returnedError else {
                Logger.log("Successfully uploaded translations.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                
                return
            }
            
            Logger.log("Couldn't upload translations.\n\(Logger.errorInfo(error))",
                       verbose: true,
                       metadata: [#file, #function, #line])
            
            completion(Logger.errorInfo(error))
        }
    }
}
