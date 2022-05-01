//
//  TranslationSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit
import Foundation

public struct TranslationSerializer {
    
    //==================================================//
    
    /* MARK: - Uploading Functions */
    
    public static func uploadTranslation(_ translation: Translation,
                                         completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        let languagePair = translation.languagePair
        let serializedTranslation = translation.serialize()
        let dictionary = [serializedTranslation.key: serializedTranslation.value]
        
        GeneralSerializer.shared.updateValue(onKey: "allTranslations/\(languagePair.asString())",
                                             withData: dictionary) { (returnedError) in
            if let error = returnedError {
                log("Couldn't upload translation.\n\(errorInfo(error))",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(errorInfo(error))
            } else {
                log("Successfully uploaded translation.",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(nil)
            }
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
        GeneralSerializer.shared.getValues(atPath: "/allTranslations/en-\(languageCode)") { (returnedValues, errorDescriptor) in
            if let values = returnedValues as? [String: String] {
                guard let decodedValues = values.hashDecoded() else {
                    log("Unable to decode values.",
                        metadata: [#file, #function, #line])
                    completion("Unable to decode values.")
                    return
                }
                
                log("Successfully downloaded translation archive.",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                let languagePair = LanguagePair(from: "en",
                                                to: languageCode)
                
                for key in decodedValues.keys {
                    let input = TranslationInput(key)
                    let translation = Translation(input: input,
                                                  output: decodedValues[key]!,
                                                  languagePair: languagePair)
                    
                    translationArchive.append(translation)
                }
            } else if let error = errorDescriptor {
                log(error, metadata: [#file, #function, #line])
                completion(error)
            } else {
                log("No online translation archive for this language pair.",
                    metadata: [#file, #function, #line])
                
                completion("No online translation archive for this language pair.")
            }
        }
    }
    
    public static func findTranslation(for input: TranslationInput,
                                       languagePair: LanguagePair,
                                       completion: @escaping(_ returnedString: String?,
                                                             _ errorDescriptor: String?) -> Void) {
        let path = "/allTranslations/\(languagePair.asString())"
        
        GeneralSerializer.shared.getValues(atPath: "\(path)/\(input.value().compressedHash)") { (returnedValues, errorDescriptor) in
            if let value = returnedValues as? String {
                guard let decoded = value.decoded(getInput: false) else {
                    completion(nil, "Failed to decode translation.")
                    return
                }
                
                completion(decoded, nil)
            } else if let error = errorDescriptor {
                completion(nil, error)
            } else {
                completion(nil, "No uploaded translation exists.")
            }
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
                if didError && verboseFunctionExposure {
                    log("At least one translation could not be found.",
                        metadata: [#file, #function, #line])
                }
                
                if Array(translationDictionary.values).filter({$0 != "!"}).count == 0 {
                    completion(nil)
                } else {
                    completion(translationDictionary)
                }
            } else {
                log("Mismatched translation input/output.",
                    isFatal: true,
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
        GeneralSerializer.shared.updateValue(onKey: "/allTranslations/\(languagePair.asString())",
                                             withData: [input.value().compressedHash: NSNull()]) { (returnedError) in
            if let error = returnedError {
                log("Couldn't remove translation.\n\(errorInfo(error))",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(errorInfo(error))
            } else {
                log("Successfully removed translation.",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(nil)
            }
        }
    }
    
    public static func removeTranslations(for inputs: [TranslationInput],
                                          languagePair: LanguagePair,
                                          completion: @escaping(_ errorDescriptor: String?) -> Void = { _ in }) {
        var nulledDictionary = [String: Any]()
        for input in inputs {
            nulledDictionary[input.value()] = NSNull()
        }
        
        GeneralSerializer.shared.updateValue(onKey: "/allTranslations/\(languagePair.asString())",
                                             withData: nulledDictionary) { (returnedError) in
            if let error = returnedError {
                log("Couldn't remove translations.\n\(errorInfo(error))",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(errorInfo(error))
            } else {
                log("Successfully removed translations.",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(nil)
            }
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
        
        GeneralSerializer.shared.updateValue(onKey: "/allTranslations/\(languagePair.asString())",
                                             withData: dictionary) { (returnedError) in
            if let error = returnedError {
                log("Couldn't upload translations.\n\(errorInfo(error))",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(errorInfo(error))
            } else {
                log("Successfully uploaded translations.",
                    verbose: true,
                    metadata: [#file, #function, #line])
                
                completion(nil)
            }
        }
    }
}
