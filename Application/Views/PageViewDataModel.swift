//
//  PageViewDataModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Translator

import AlertKit

public class PageViewDataModel {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private var inputs: [String: Translator.TranslationInput]!
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(inputs: [String: Translator.TranslationInput]) {
        self.inputs = inputs
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func translateStrings(completion: @escaping (_ returnedTranslations: [String: Translator.Translation]?,
                                                        _ returnedException: Exception?) -> Void) {
        let timeout = Timeout(alertingAfter: 10, metadata: [#file, #function, #line])
        
        FirebaseTranslator.shared.getTranslations(for: Array(inputs.values),
                                                  languagePair: Translator.LanguagePair(from: "en",
                                                                                        to: RuntimeStorage.languageCode!),
                                                  using: .google) { returnedTranslations,
            exception in
            timeout.cancel()
            
            guard let translations = returnedTranslations else {
                completion(nil, exception)
                return
            }
            
            guard let matchedTranslations = translations.matchedTo(self.inputs) else {
                completion(nil, Exception("Couldn't match translations with inputs.",
                                          metadata: [#file, #function, #line]))
                return
            }
            
            completion(matchedTranslations, nil)
        }
    }
}
