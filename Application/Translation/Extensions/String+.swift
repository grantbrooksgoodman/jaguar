//
//  String+.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit
import Foundation

public extension String {
    /* MARK: - Functions */
    
    func asLanguagePair() -> LanguagePair? {
        let components = self.components(separatedBy: "-")
        
        guard components.count == 2 else {
            return nil
        }
        
        return LanguagePair(from: components[0],
                            to: components[1])
    }
    
    func decoded(getInput: Bool) -> String? {
        let halves = self.components(separatedBy: "–")
        
        guard halves.count == 2 else {
            return nil
        }
        
        guard let decoded = getInput ? halves[0].removingPercentEncoding : halves[1].removingPercentEncoding else {
            return nil
        }
        
        return decoded
    }
    
    func inconsideratelyMatchingCapitalization(of: String) -> String {
        let comparatorSplit = `of`.components(separatedBy: " ")
        let selfSplit = components(separatedBy: " ")
        
        guard comparatorSplit.count != 0 && comparatorSplit[0] != "" else {
            return self
        }
        
        var newString = ""
        
        for (index, word) in selfSplit.enumerated() {
            if index >= comparatorSplit.count {
                newString += "\(word) "
            } else {
                if comparatorSplit[index].characterArray[0].isUppercase {
                    newString += "\(word.firstUppercase) "
                } else {
                    newString += "\(word.firstLowercase) "
                }
            }
        }
        
        return newString.trimmingTrailingWhitespace
    }
    
    func matchingCapitalization(of: String) -> String {
        guard self.components(separatedBy: " ").count == `of`.components(separatedBy: " ").count else {
            return self
        }
        
        return inconsideratelyMatchingCapitalization(of: `of`)
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var alphaEncoded: String {
        return self.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
    
    var compressedHash: String {
        let compressedData = try? (Data(self.utf8) as NSData).compressed(using: .lzfse)
        
        guard let data = compressedData else {
            return SHA256.hash(data: Data(self.utf8)).compactMap { String(format: "%02x", $0) }.joined()
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
