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
    
    /* MARK: - Public Methods */
    
    public func getTranslations(for inputs: [TranslationInput],
                                languagePair: LanguagePair,
                                requiresHUD: Bool? = nil,
                                using: TranslationPlatform? = nil,
                                completion: @escaping(_ returnedTranslations: [Translation]?,
                                                      _ exception: Exception?) -> Void) {
        guard !(languagePair.from == "en" && languagePair.to == "en") else {
            var translations = [Translator.Translation]()
            
            for input in inputs {
                let processedInput = TranslationInput(input.original/*.removingOccurrences(of: ["*"])*/,
                                                      alternate: input.alternate/*?.removingOccurrences(of: ["*"])*/)
                let translation = Translation(input: processedInput,
                                              output: processedInput.original,
                                              languagePair: languagePair)
                translations.append(translation)
            }
            
            completion(translations, nil)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        var translations = [Translator.Translation]()
        var exceptions = [Exception]()
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        for (index, input) in inputs.enumerated() {
            dispatchGroup.enter()
            
            self.translate(input,
                           with: languagePair,
                           requiresHUD: requiresHUD,
                           using: using ?? .google) { (returnedTranslation, exception) in
                if let translation = returnedTranslation {
                    translations.append(translation)
                }
                //else
                if let unwrappedException = exception {
                    exceptions.append(unwrappedException.appending(extraParams: ["TranslationInputOriginal": input.original,
                                                                                 "TranslationInputAlternate": input.alternate ?? ""]))
                }
                
                Logger.logToStream("Translated item \(index + 1) of \(inputs.count).",
                                   line: #line)
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            Logger.closeStream(message: "All strings should be translated; complete.",
                               onLine: #line)
            
            if translations.count + exceptions.count == inputs.count {
                completion(translations.isEmpty ? nil : translations,
                           exceptions.compiledException)
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
                                                 _ exception: Exception?) -> Void) {
        if input.value().rangeOfCharacter(from: CharacterSet.letters) == nil {
            let processedInput = TranslationInput(input.original/*.removingOccurrences(of: ["*"])*/,
                                                  alternate: input.alternate/*?.removingOccurrences(of: ["*"])*/)
            let translation = Translation(input: processedInput,
                                          output: processedInput.original,
                                          languagePair: languagePair)
            
            TranslationSerializer.uploadTranslation(translation)
            TranslationArchiver.addToArchive(translation)
            
            completion(translation, nil)
            return
        }
        
        if let archivedTranslation = TranslationArchiver.getFromArchive(input,
                                                                        languagePair: languagePair) {
            completion(archivedTranslation, nil)
            return
        }
        
        TranslationSerializer.findTranslation(for: input,
                                              languagePair: languagePair) { (returnedString,
                                                                             exception) in
            if let translatedString = returnedString {
                Logger.log("No need to use translator; found uploaded string.",
                           verbose: true,
                           metadata: [#file, #function, #line])
                
                let translation = Translation(input: input,
                                              output: translatedString.matchingCapitalization(of: input.value()),
                                              languagePair: languagePair)
                
                TranslationArchiver.addToArchive(translation)
                
                completion(translation, nil)
            } else {
                var hasCompleted = false
                
                Core.gcd.after(milliseconds: 750) {
                    if !hasCompleted,
                       let required = requiresHUD,
                       required {
                        Core.hud.showProgress()
                    }
                }
                
                self.translate(input.value(),
                               from: languagePair.from,
                               to: languagePair.to,
                               using: using ?? .google) { (returnedString,
                                                           errorDescriptor) in
                    guard let translatedString = returnedString else {
                        // #warning("Clean this up.")
                        if let descriptor = errorDescriptor,
                           descriptor == "Couldn't translate the requested string." {
                            let translation = Translation(input: input,
                                                          output: input.value(),
                                                          languagePair: languagePair)
                            
                            TranslationSerializer.uploadTranslation(translation)
                            TranslationArchiver.addToArchive(translation)
                            
                            if let required = requiresHUD,
                               required {
                                Core.hud.hide()
                            }
                            
                            hasCompleted = true
                            completion(translation, nil)
                        } else {
                            let exception = Exception(errorDescriptor, metadata: [#file, #function, #line])
                            
                            Logger.log(exception)
                            //                            completion(nil, exception)
                        }
                        
                        return
                    }
                    
                    let translation = Translation(input: input,
                                                  output: translatedString.matchingCapitalization(of: input.value()),
                                                  languagePair: languagePair)
                    
                    TranslationSerializer.uploadTranslation(translation)
                    TranslationArchiver.addToArchive(translation)
                    
                    if let required = requiresHUD,
                       required {
                        Core.hud.hide()
                    }
                    
                    hasCompleted = true
                    completion(translation, nil)
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
                let exception = Exception(errorDescriptor,
                                          metadata: [#file, #function, #line])
                
                Logger.log(exception)
                completion(nil, exception.descriptor)
                return
            }
            
            completion(translation.output, nil)
        }
    }
}
