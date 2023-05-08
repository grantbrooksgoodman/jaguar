//
//  PhoneNumber.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 03/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit
import Foundation

public struct PhoneNumber: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    public var callingCode: String?
    public var digits: String!
    public var formattedString: String?
    public var label: String?
    
    // Other
    public var rawStringHasPlusPrefix: Bool
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(digits: String!,
                rawStringHasPlusPrefix: Bool,
                label: String? = nil,
                formattedString: String? = nil,
                callingCode: String? = nil) {
        self.digits = digits
        self.rawStringHasPlusPrefix = rawStringHasPlusPrefix
        self.label = label
        self.formattedString = formattedString
        self.callingCode = callingCode
    }
    
    //==================================================//
    
    /* MARK: - Hashing Methods */
    
    public func hashSerialized() -> [String] {
        var hashFactors = [String]()
        
        hashFactors.append(digits)
        hashFactors.append(rawStringHasPlusPrefix.description)
        hashFactors.append(label ?? "")
        hashFactors.append(formattedString ?? "")
        hashFactors.append(callingCode ?? "")
        
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

public extension Array where Element == String {
    var digits: [String] {
        var digits = [String]()
        
        for element in self {
            digits.append(element.digits)
        }
        
        return digits
    }
}

/* MARK: - Data */
public extension Data {
    var compressedHash: String {
        let compressedData = try? (self as NSData).compressed(using: .lzfse)
        
        guard let data = compressedData else {
            return SHA256.hash(data: self).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
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
