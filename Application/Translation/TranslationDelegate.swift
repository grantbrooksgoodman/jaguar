//
//  TranslationDelegate.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import AlertKit
import Translator

public struct TranslationDelegate: AKTranslationDelegate {
    
    //==================================================//
    
    /* MARK: - Protocol Conformance */
    
    public func getTranslations(for inputs: [AlertKit.TranslationInput],
                                languagePair: AlertKit.LanguagePair,
                                requiresHUD: Bool?,
                                using platform: AlertKit.PlatformName?,
                                completion: @escaping (_ returnedTranslations: [AlertKit.Translation]?,
                                                       _ errorDescriptors: [String: AlertKit.TranslationInput]?) -> Void) {
        var convertedInputs = [Translator.TranslationInput]()
        
        for input in inputs {
            convertedInputs.append(Translator.TranslationInput(input.original, alternate: input.alternate))
        }
        
        let convertedLanguagePair = Translator.LanguagePair(from: languagePair.from, to: languagePair.to)
        
        FirebaseTranslator.shared.getTranslations(for: convertedInputs,
                                                  languagePair: convertedLanguagePair,
                                                  requiresHUD: requiresHUD) { returnedTranslations,
            exception in
            guard let translations = returnedTranslations else {
                var convertedErrorDescriptors = [String: AlertKit.TranslationInput]()
                
                guard let exception = exception,
                      let extraParams = exception.extraParams,
                      let original = extraParams["TranslationInputOriginal"] as? String,
                      let alternate = extraParams["TranslationInputAlternate"] as? String else {
                    // #warning("This probably isn't the greatest way to deal with this.")
                    convertedErrorDescriptors[exception?.descriptor ?? String(Int().random(min: 0, max: 10))] = AlertKit.TranslationInput("")
                    completion(nil, convertedErrorDescriptors)
                    return
                }
                
                let convertedTranslationInput = AlertKit.TranslationInput(original,
                                                                          alternate: alternate)
                
                convertedErrorDescriptors[exception.descriptor] = convertedTranslationInput
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
