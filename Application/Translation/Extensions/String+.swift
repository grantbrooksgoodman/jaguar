//
//  String+.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 31/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit

/* Third-party Frameworks */
import Translator

public extension String {
    /* MARK: - Functions */
    
    func decoded(getInput: Bool) -> String? {
        let halves = components(separatedBy: "–")
        
        guard halves.count == 2 else { return nil }
        
        guard let decoded = getInput ? halves[0].removingPercentEncoding : halves[1].removingPercentEncoding else { return nil }
        
        return decoded
    }
    
    // --------------------------------------------------//
    
    /* MARK: - Variables */
    
    var alphaEncoded: String {
        return addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
    
    var compressedHash: String {
        let compressedData = try? (Data(utf8) as NSData).compressed(using: .lzfse)
        
        guard let data = compressedData else {
            return SHA256.hash(data: Data(utf8)).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    var trimmingTrailingNewlines: String {
        var mutableSelf = self
        
        while mutableSelf.hasSuffix("\n") {
            mutableSelf = mutableSelf.dropSuffix(1)
        }
        
        return mutableSelf
    }
}

public extension Data {
    var compressedHash: String {
        let compressedData = try? (self as NSData).compressed(using: .lzfse)
        
        guard let data = compressedData else {
            return SHA256.hash(data: self).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
