//
//  PageViewDataModel.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Translator

public class PageViewDataModel {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    private var inputs: [String: TranslationInput]!
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(inputs: [String: TranslationInput]) {
        self.inputs = inputs
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func translateStrings(completion: @escaping(_ returnedTranslations: [String: Translation]?,
                                                       _ errorDescriptor: String?) -> Void) {
        FirebaseTranslator.shared.getTranslations(for: Array(inputs.values),
                                                  languagePair: LanguagePair(from: "en",
                                                                             to: languageCode),
                                                  using: .google) { (returnedTranslations,
                                                                     errorDescriptors) in
            guard let translations = returnedTranslations else {
                completion(nil, errorDescriptors?.keys.joined(separator: "\n") ?? "An unknown error occurred.")
                return
            }
            
            guard let matchedTranslations = translations.matchedTo(self.inputs) else {
                completion(nil, "Couldn't match translations with inputs.")
                return
            }
            
            completion(matchedTranslations, nil)
        }
    }
}
