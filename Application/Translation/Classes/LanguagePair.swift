//
//  LanguagePair.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public class LanguagePair: Codable {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    public var from: String
    public var to: String
    
    //==================================================//
    
    /* MARK: - Initializer Function */
    
    public init(from: String,
                to: String) {
        self.from = from
        self.to = to
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    public func asString() -> String {
        return "\(from)-\(to)"
    }
}
