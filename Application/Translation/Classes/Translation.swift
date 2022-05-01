//
//  Translation.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public class Translation: Codable {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public var input: TranslationInput
    public var output: String
    public var languagePair: LanguagePair
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(input: TranslationInput,
                output: String,
                languagePair: LanguagePair) {
        self.input = input
        self.output = output
        self.languagePair = languagePair
    }
    
    //==================================================//
    
    /* MARK: - Serialization Functions */
    
    public func serialize() -> (key: String, value: String) {
        let value = input.value()
        
        return ("\(value.compressedHash)", "\(value.alphaEncoded)–\(output.matchingCapitalization(of: value).alphaEncoded)")
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func matchingInput(inputs: [String: TranslationInput]) -> (key: String,
                                                                      translation: Translation)? {
        //Should be able to use guard here.
        for key in inputs.keys {
            let value = inputs[key]!
            
            if let translationAlternate = self.input.alternate {
                if value.original == translationAlternate || value.alternate == translationAlternate {
                    return (key, self)
                }
            }
            
            if value.original == self.input.original {
                return (key, self)
            }
            
            if let inputAlternate = value.alternate {
                if self.input.original == inputAlternate || self.input.alternate == inputAlternate {
                    
                    return (key, self)
                }
            }
        }
        
        return nil
    }
}


