//
//  Array+.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import Translator

public extension Array where Element == Translation {
    func homogeneousLanguagePairs() -> Bool {
        var pairs = [String]()
        
        for element in self {
            pairs.append(element.languagePair.asString())
            pairs = pairs.unique()
        }
        
        return !(pairs.count > 1)
    }
    
    func languagePairs() -> [LanguagePair] {
        var pairStrings = [String]()
        
        for element in self {
            pairStrings.append(element.languagePair.asString())
        }
        
        pairStrings = pairStrings.unique()
        
        var pairs = [LanguagePair]()
        
        #warning("Think about whether this should be optional return.")
        for pairString in pairStrings {
            if let languagePair = pairString.asLanguagePair() {
                pairs.append(languagePair)
            }
        }
        
        return pairs
    }
    
    func matchedTo(_ inputs: [String: TranslationInput]) -> [String: Translation]? {
        var translationDictionary = [String: Translation]()
        
        for translation in self {
            if let matchingInput = translation.matchingInput(inputs: inputs) {
                translationDictionary[matchingInput.key] = matchingInput.translation
            }
        }
        
        return translationDictionary.count != inputs.count ? nil : translationDictionary
    }
    
    func `where`(languagePair: LanguagePair) -> [Translation] {
        var matching = [Translation]()
        
        for element in self {
            if element.languagePair.asString() == languagePair.asString() {
                matching.append(element)
            }
        }
        
        return matching
    }
}
