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
                                using: PlatformName? = nil,
                                completion: @escaping(_ returnedTranslations: [Translation]?,
                                                      _ exception: Exception?) -> Void) {
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
        var exceptions = [Exception]()
        
        Logger.openStream(metadata: [#file, #function, #line])
        
        for (index, input) in inputs.enumerated() {
            dispatchGroup.enter()
            
            self.translate(input,
                           with: languagePair,
                           requiresHUD: requiresHUD,
                           using: using ?? .google) { translation, exception in
                if let translation {
                    translations.append(translation)
                }
                //else
                if let exception {
                    exceptions.append(exception.appending(extraParams: ["TranslationInputOriginal": input.original,
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
                          using: PlatformName? = nil,
                          completion: @escaping (_ returnedTranslation: Translation?,
                                                 _ exception: Exception?) -> Void) {
        if let archivedTranslation = TranslationArchiver.getFromArchive(input, languagePair: languagePair) {
            completion(archivedTranslation, nil)
            return
        }
        
        guard input.value().rangeOfCharacter(from: CharacterSet.letters) != nil,
              languagePair.from != languagePair.to else {
            let translation = Translation(input: input,
                                          output: input.original,
                                          languagePair: languagePair)
            
            DispatchQueue.global(qos: .userInteractive).async { TranslationSerializer.uploadTranslation(translation) }
            TranslationArchiver.addToArchive(translation)
            
            completion(translation, nil)
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
                               using: using ?? .google) { translatedString, errorDescriptor in
                    guard let translatedString else {
                        // #warning("Clean this up.")
                        if let descriptor = errorDescriptor,
                           descriptor == "Couldn't translate the requested string." {
                            let translation = Translation(input: input,
                                                          output: input.value(),
                                                          languagePair: languagePair)
                            
                            DispatchQueue.global(qos: .userInteractive).async { TranslationSerializer.uploadTranslation(translation) }
                            TranslationArchiver.addToArchive(translation)
                            
                            if let required = requiresHUD,
                               required {
                                Core.hud.hide()
                            }
                            
                            hasCompleted = true
                            completion(translation, nil)
                        } else {
                            if let required = requiresHUD,
                               required {
                                Core.hud.hide()
                            }
                            
                            hasCompleted = true
                            completion(nil, Exception(errorDescriptor, metadata: [#file, #function, #line]))
                        }
                        
                        return
                    }
                    
                    let translation = Translation(input: input,
                                                  output: translatedString.matchingCapitalization(of: input.value()),
                                                  languagePair: languagePair)
                    
                    DispatchQueue.global(qos: .userInteractive).async { TranslationSerializer.uploadTranslation(translation) }
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
                          from sourceLanguage: String,
                          to targetLanguage: String,
                          using platform: Translator.PlatformName,
                          completion: @escaping (String?, String?) -> Void) {
        guard text.lowercasedTrimmingWhitespace != "" else {
            completion("", nil)
            return
        }
        
        let input = Translator.TranslationInput(text)
        let languagePair = Translator.LanguagePair(from: sourceLanguage,
                                                   to: targetLanguage)
        
        TranslatorService.shared.translate(input,
                                           with: languagePair,
                                           using: platform) { translation, errorDescriptor in
            guard let translation else {
                let exception = Exception(errorDescriptor, metadata: [#file, #function, #line])
                completion(nil, exception.descriptor)
                return
            }
            
            completion(translation.output, nil)
        }
    }
}
