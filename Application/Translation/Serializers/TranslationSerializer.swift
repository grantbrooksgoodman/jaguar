//
//  TranslationSerializer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit
import UIKit

/* Third-party Frameworks */
import AlertKit
import Translator

public enum TranslationSerializer {
    
    //==================================================//
    
    /* MARK: - Uploading Methods */
    
    public static func uploadTranslation(_ translation: Translator.Translation,
                                         completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        let languagePair = translation.languagePair
        let serializedTranslation = translation.serialize()
        let dictionary = [serializedTranslation.key: serializedTranslation.value]
        
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/translations"
        GeneralSerializer.updateChildValues(forKey: "\(pathPrefix)/\(languagePair.asString())",
                                            with: dictionary) { exception in
            guard let exception else {
                Logger.log("Successfully uploaded translation.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                
                return
            }
            
            completion(exception.appending(extraParams: ["UserFacingDescriptor": "Couldn't upload translation."]))
        }
    }
    
    public static func uploadTranslations(_ translations: [Translator.Translation],
                                          completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        let languagePairs = translations.languagePairs()
        let dispatchGroup = DispatchGroup()
        
        var exceptions = [Exception]()
        
        for pair in languagePairs {
            dispatchGroup.enter()
            
            uploadTranslations(translations.where(languagePair: pair),
                               for: pair) { (exception) in
                if let error = exception {
                    exceptions.append(error.appending(extraParams: ["languagePair": pair.asString()]))
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(exceptions.compiledException)
        }
    }
    
    //==================================================//
    
    /* MARK: - Downloading Methods */
    
    public static func downloadTranslations(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
#warning("Figure out whether the limit will cause any issues. It shouldn't, because we have findTranslation() as a backup, but still.")
        
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/translations"
        GeneralSerializer.queryValues(atPath: "\(pathPrefix)/en-\(RuntimeStorage.languageCode!)",
                                      limit: 50) { (returnedValues,
                                                    exception) in
            guard let values = returnedValues as? [String: String] else {
                let error = exception ?? Exception("No online translation archive for this language pair.",
                                                   extraParams: ["LanguagePair": "en-\(RuntimeStorage.languageCode!)"],
                                                   metadata: [#file, #function, #line])
                
                if RuntimeStorage.languageCode! != "en" {
                    Logger.log(error)
                }
                
                completion(error)
                return
            }
            
            guard let decodedValues = values.hashDecoded() else {
                let exception = Exception("Unable to decode values.", metadata: [#file, #function, #line])
                completion(exception)
                
                return
            }
            
            Logger.log("Successfully downloaded translation archive.",
                       verbose: true,
                       metadata: [#file, #function, #line])
            
            let languagePair = Translator.LanguagePair(from: "en",
                                                       to: RuntimeStorage.languageCode!)
            
            for (index, key) in decodedValues.keys.enumerated() {
                let input = Translator.TranslationInput(key)
                let translation = Translator.Translation(input: input,
                                                         output: decodedValues[key]!,
                                                         languagePair: languagePair)
                
                TranslationArchiver.addToArchive(translation)
                
                if index == decodedValues.count - 1 {
#if !EXTENSION
                    let keyWindow = UIApplication.shared.windows.filter { $0.isKeyWindow }.first
                    
                    if var topController = keyWindow?.rootViewController {
                        while let presentedViewController = topController.presentedViewController {
                            topController = presentedViewController
                        }
                        
                        if topController.isKind(of: UIAlertController.self) {
                            topController.dismiss(animated: true)
                            AKCore.shared.setLanguageCode(RuntimeStorage.languageCode!)
                        }
                    }
#endif
                    
                    completion(nil)
                }
            }
        }
    }
    
    public static func findTranslation(withReference: String,
                                       languagePair: Translator.LanguagePair,
                                       completion: @escaping(_ returnedTranslation: Translator.Translation?,
                                                             _ exception: Exception?) -> Void) {
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/translations"
        let path = "\(pathPrefix)/\(languagePair.asString())"
        
        GeneralSerializer.getValues(atPath: "\(path)/\(withReference)") { (returnedValues,
                                                                           exception) in
            guard let value = returnedValues as? String else {
                if returnedValues as? NSNull != nil {
                    completion(nil, Exception("No translations for the provided language pair.",
                                              extraParams: ["LanguagePair": languagePair.asString()],
                                              metadata: [#file, #function, #line]))
                } else {
                    let error = exception ?? Exception(metadata: [#file, #function, #line])
                    
                    Logger.log(error)
                    completion(nil, error)
                }
                
                return
            }
            
            guard let decodedInput = value.decoded(getInput: true),
                  let decodedOutput = value.decoded(getInput: false) else {
                completion(nil, Exception("Failed to decode translation.", metadata: [#file, #function, #line]))
                return
            }
            
            let translation = Translation(input: TranslationInput(decodedInput),
                                          output: decodedOutput,
                                          languagePair: languagePair)
            
            completion(translation, nil)
        }
    }
    
    public static func findTranslation(for input: Translator.TranslationInput,
                                       languagePair: Translator.LanguagePair,
                                       completion: @escaping(_ returnedString: String?,
                                                             _ exception: Exception?) -> Void) {
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/translations"
        let path = "\(pathPrefix)/\(languagePair.asString())"
        
        GeneralSerializer.getValues(atPath: "\(path)/\(input.value().compressedHash)") { (returnedValues, exception) in
            guard let value = returnedValues as? String else {
                completion(nil, exception ?? Exception("No uploaded translation exists.",
                                                       metadata: [#file, #function, #line]))
                return
            }
            
            guard let decoded = value.decoded(getInput: false) else {
                completion(nil, Exception("Failed to decode translation.", metadata: [#file, #function, #line]))
                return
            }
            
            completion(decoded, nil)
        }
    }
    
    public static func findTranslations(_ for: [Translator.TranslationInput],
                                        languagePair: Translator.LanguagePair,
                                        completion: @escaping(_ returnedStrings: [String: String]?) -> Void) {
        let dispatchGroup = DispatchGroup()
        
        var translationDictionary = [String: String]()
        var didError = false
        
        for input in `for` {
            dispatchGroup.enter()
            
            findTranslation(for: input,
                            languagePair: languagePair) { (returnedString, exception) in
                if let translatedString = returnedString {
                    translationDictionary[input.value()] = translatedString
                } else if exception != nil {
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
                
                if Array(translationDictionary.values).filter({$0 != "!"}).isEmpty {
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
    
    /* MARK: - Removal Methods */
    
    public static func removeTranslation(for input: Translator.TranslationInput,
                                         languagePair: Translator.LanguagePair,
                                         completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/translations"
        GeneralSerializer.updateChildValues(forKey: "\(pathPrefix)/\(languagePair.asString())",
                                            with: [input.value().compressedHash: NSNull()]) { exception in
            guard let exception else {
                Logger.log("Successfully removed translation.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                return
            }
            
            completion(exception.appending(extraParams: ["UserFacingDescriptor": "Couldn't remove translation."]))
        }
    }
    
    public static func removeTranslations(for inputs: [Translator.TranslationInput],
                                          languagePair: Translator.LanguagePair,
                                          completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        var nulledDictionary = [String: Any]()
        for input in inputs {
            nulledDictionary[input.value().compressedHash] = NSNull()
        }
        
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/translations"
        GeneralSerializer.updateChildValues(forKey: "\(pathPrefix)/\(languagePair.asString())",
                                            with: nulledDictionary) { exception in
            guard let exception else {
                Logger.log("Successfully removed translations.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                
                return
            }
            
            completion(exception.appending(extraParams: ["UserFacingDescriptor": "Couldn't remove translations."]))
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private static func uploadTranslations(_ translations: [Translator.Translation],
                                           for languagePair: Translator.LanguagePair,
                                           completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        guard translations.homogeneousLanguagePairs() else {
            completion(Exception("Translations are not all from the same language!", metadata: [#file, #function, #line]))
            return
        }
        
        var dictionary = [String: String]()
        
        for translation in translations {
            let serialized = translation.serialize()
            
            dictionary[serialized.key] = serialized.value
        }
        
        let pathPrefix = "\(GeneralSerializer.environment.shortString)/translations"
        GeneralSerializer.updateChildValues(forKey: "\(pathPrefix)/\(languagePair.asString())",
                                            with: dictionary) { exception in
            guard let exception else {
                Logger.log("Successfully uploaded translations.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                completion(nil)
                
                return
            }
            
            completion(exception.appending(extraParams: ["UserFacingDescriptor": "Couldn't upload translations."]))
        }
    }
}
