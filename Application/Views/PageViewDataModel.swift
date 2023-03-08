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
    
    /* MARK: - Properties */
    
    private var inputs: [String: TranslationInput]!
    
    //==================================================//
    
    /* MARK: - Constructor Method */
    
    public init(inputs: [String: TranslationInput]) {
        self.inputs = inputs
    }
    
    //==================================================//
    
    /* MARK: - String Translation */
    
    public func translateStrings(completion: @escaping (_ returnedTranslations: [String: Translation]?,
                                                        _ returnedException: Exception?) -> Void) {
        let timeout = Timeout(alertingAfter: 10, metadata: [#file, #function, #line])
        
        FirebaseTranslator.shared.getTranslations(for: Array(inputs.values),
                                                  languagePair: LanguagePair(from: "en",
                                                                             to: RuntimeStorage.languageCode!),
                                                  using: .google) { returnedTranslations,
            exception in
            timeout.cancel()
            
            guard let translations = returnedTranslations else {
                completion(nil, exception)
                return
            }
            
            guard let matchedTranslations = translations.matchedTo(self.inputs) else {
                completion(nil, Exception("Couldn't match translations with inputs.", metadata: [#file, #function, #line]))
                return
            }
            
            let stripped = self.stripTranslations(matchedTranslations)
            completion(stripped, nil)
            
#warning("^ Do we need to specifically do it for English-English translations?")
            //            if translations.languagePairs().allSatisfy({ $0.from == "en" && $0.to == "en" }) {
            //                let stripped = self.stripTranslations(matchedTranslations)
            //                completion(stripped, nil)
            //            } else {
            //                completion(matchedTranslations, nil)
            //            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func stripTranslations(_ translationPairs: [String: Translation]) -> [String: Translation] {
        // Since this is for a Page View, it's always going to be translating strings that I put in.
        // So, we're safe to remove all "*".
        
        var strippedTranslations = [String: Translation]()
        
        for pair in translationPairs.sorted(by: { $0.key < $1.key }) {
            let translation = pair.value
            let newInput = TranslationInput(translation.input.original.removingOccurrences(of: ["*"]),
                                            alternate: translation.input.alternate?.removingOccurrences(of: ["*"]))
            
            strippedTranslations[pair.key] = Translation(input: newInput,
                                                         output: translation.output.removingOccurrences(of: ["*"]),
                                                         languagePair: translation.languagePair)
        }
        
        return strippedTranslations
    }
}
