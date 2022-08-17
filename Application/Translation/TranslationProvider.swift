//
//  TranslationProvider.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import AlertKit
import Translator

public class TranslationProvider: AKTranslationProvider {
    
    //==================================================//
    
    /* MARK: - Protocol Compliance Function */
    
    public func getTranslations(for inputs: [AlertKit.TranslationInput],
                                languagePair: AlertKit.LanguagePair,
                                requiresHUD: Bool?,
                                using: AlertKit.TranslationPlatform?,
                                completion: @escaping(_ returnedTranslations: [AlertKit.Translation]?,
                                                      _ errorDescriptor: [String: AlertKit.TranslationInput]?) -> Void) {
        var convertedInputs = [Translator.TranslationInput]()
        
        for input in inputs {
            convertedInputs.append(Translator.TranslationInput(input.original, alternate: input.alternate))
        }
        
        let convertedLanguagePair = Translator.LanguagePair(from: languagePair.from, to: languagePair.to)
        
        FirebaseTranslator.shared.getTranslations(for: convertedInputs,
                                                  languagePair: convertedLanguagePair,
                                                  requiresHUD: requiresHUD) { (returnedTranslations,
                                                                               errorDescriptors) in
            guard let translations = returnedTranslations else {
                Logger.log(errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                
                var convertedErrorDescriptors = [String: AlertKit.TranslationInput]()
                
                for errorDescriptor in errorDescriptors!.keys {
                    let convertedTranslationInput = AlertKit.TranslationInput(errorDescriptors![errorDescriptor]!.original,
                                                                              alternate: errorDescriptors![errorDescriptor]!.alternate)
                    
                    convertedErrorDescriptors[errorDescriptor] = convertedTranslationInput
                }
                
                completion(nil, convertedErrorDescriptors)
                
                return
            }
            
            var convertedTranslations = [AlertKit.Translation]()
            
            for translation in translations {
                let convertedInput = AlertKit.TranslationInput(translation.input.original, alternate: translation.input.alternate)
                let convertedLanguagePair = AlertKit.LanguagePair(from: translation.languagePair.from,
                                                                  to: translation.languagePair.to)
                
                let akTranslation = AlertKit.Translation(input: convertedInput,
                                                         output: translation.output,
                                                         languagePair: convertedLanguagePair)
                
                convertedTranslations.append(akTranslation)
            }
            
            completion(convertedTranslations, nil)
        }
    }
}
