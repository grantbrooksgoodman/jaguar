//
//  PhoneNumber.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 03/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct PhoneNumber: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    public var digits: String!
    public var label: String?
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(digits: String!, label: String? = nil) {
        self.digits = digits
        self.label = label
    }
    
    //==================================================//
    
    /* MARK: - Hashing Functions */
    
    public func hashSerialized() -> [String] {
        var hashFactors = [String]()
        
        hashFactors.append(digits)
        hashFactors.append(label ?? "")
        
        return hashFactors
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - Array */
public extension Array where Element == PhoneNumber {
    var digits: [String] {
        var digits = [String]()
        
        for item in self {
            digits.append(item.digits)
        }
        
        return digits
    }
    
    var labels: [String] {
        var labels = [String]()
        
        for item in self {
            labels.append(item.label ?? "")
        }
        
        return labels
    }
}

/* MARK: - PhoneNumber */
public extension PhoneNumber {
    var hash: String {
        do {
            let encoder = JSONEncoder()
            let encodedPhoneNumber = try! encoder.encode(self.hashSerialized())
            
            return encodedPhoneNumber.compressedHash
        }
    }
}
