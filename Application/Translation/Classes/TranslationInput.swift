//
//  TranslationInput.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public class TranslationInput: Codable {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public var original: String
    public var alternate: String?
    
    //==================================================//
    
    /* MARK: - Initializer Functions */
    
    public init(_ original: String,
                alternate: String?) {
        self.original = original
        self.alternate = alternate
    }
    
    public convenience init(_ original: String) {
        self.init(original,
                  alternate: nil)
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func value() -> String {
        guard let alternate = alternate else {
            return original
        }
        
        return alternate
    }
}
