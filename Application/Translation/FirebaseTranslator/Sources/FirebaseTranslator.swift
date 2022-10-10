//
//  FirebaseTranslator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Translator

public struct FirebaseTranslator: Translatorable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static var shared = FirebaseTranslator()
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func getTranslations(for inputs: [TranslationInput],
                                languagePair: LanguagePair,
                                requiresHUD: Bool? = nil,
                                using: TranslationPlatform? = nil,
                                completion: @escaping(_ returnedTranslations: [Translation]?,
                                                      _ errorDescriptors: [String: TranslationInput]?) -> Void) {
        guard !(languagePair.from == "en" && languagePair.to == "en") else {
            var translations = [Translator.Translation]()
            
            for input in inputs {
                let translation = Translation(input: input,
                                              output: input.original,
                                              languagePair: languagePair)
                translations.append(translation)
            }
            
            completion(translations, nil)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        var translations = [Translator.Translation]()
        var errors = [String: Translator.TranslationInput]()
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        for (index, input) in inputs.enumerated() {
            dispatchGroup.enter()
            
            self.translate(input,
                           with: languagePair,
                           requiresHUD: requiresHUD,
                           using: using ?? .google) { (returnedTranslation, errorDescriptor) in
                if let translation = returnedTranslation {
                    translations.append(translation)
                }
                //else
                if let error = errorDescriptor {
                    errors[error] = input
                }
                
                Logger.logToStream("Translated item \(index + 1) of \(inputs.count).",
                                   line: #line)
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            Logger.closeStream(message: "All strings should be translated; complete.",
                               onLine: #line)
            
            if translations.count + errors.count == inputs.count {
                completion(translations.isEmpty ? nil : translations,
                           errors.isEmpty ? nil : errors)
            } else {
                Logger.log("Mismatched translation input/output.",
                           with: .fatalAlert,
                           metadata: [#file, #function, #line])
                completion(nil, nil)
            }
        }
    }
    
    public func instance() -> Translatorable {
        return FirebaseTranslator()
    }
    
    public func translate(_ input: TranslationInput,
                          with languagePair: LanguagePair,
                          requiresHUD: Bool? = nil,
                          using: TranslationPlatform? = nil,
                          completion: @escaping (_ returnedTranslation: Translation?,
                                                 _ errorDescriptor: String?) -> Void) {
        if let archivedTranslation = TranslationArchiver.getFromArchive(input,
                                                                        languagePair: languagePair) {
            completion(archivedTranslation, nil)
            return
        }
        
        if let required = requiresHUD,
           required {
            //            showProgressHUD()
        }
        
        TranslationSerializer.findTranslation(for: input,
                                              languagePair: languagePair) { (returnedString,
                                                                             errorDescriptor) in
            if let translatedString = returnedString {
                Logger.log("No need to use translator; found uploaded string.",
                           metadata: [#file, #function, #line])
                
                let translation = Translation(input: input,
                                              output: translatedString.matchingCapitalization(of: input.value()),
                                              languagePair: languagePair)
                
                TranslationArchiver.addToArchive(translation)
                
                completion(translation, nil)
            } else {
                self.translate(input.value(),
                               from: languagePair.from,
                               to: languagePair.to,
                               using: using ?? .google) { (returnedString,
                                                           errorDescriptor) in
                    guard let translatedString = returnedString else {
                        Logger.log(errorDescriptor ?? "An unknown error occurred.",
                                   metadata: [#file, #function, #line])
                        return
                    }
                    
                    let translation = Translation(input: input,
                                                  output: translatedString.matchingCapitalization(of: input.value()),
                                                  languagePair: languagePair)
                    
                    TranslationSerializer.uploadTranslation(translation)
                    TranslationArchiver.addToArchive(translation)
                    
                    completion(translation, nil)
                    
                    if let required = requiresHUD,
                       required {
                        Core.hud.hide(delay: 0.2)
                    }
                }
            }
        }
    }
    
    public func translate(_ text: String,
                          from: String,
                          to: String,
                          using: TranslationPlatform,
                          completion: @escaping (String?, String?) -> Void) {
        guard text.lowercasedTrimmingWhitespace != "" else {
            completion("", nil)
            return
        }
        
        let input = Translator.TranslationInput(text)
        let languagePair = Translator.LanguagePair(from: from,
                                                   to: to)
        
        TranslatorService.shared.translate(input,
                                           with: languagePair) { (returnedTranslation,
                                                                  errorDescriptor) in
            guard let translation = returnedTranslation else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                completion(nil, error)
                return
            }
            
            completion(translation.output, nil)
        }
    }
}
