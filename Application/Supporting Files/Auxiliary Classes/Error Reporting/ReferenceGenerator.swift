//
//  ReferenceGenerator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit
import Foundation

public struct ReferenceGenerator {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private static var wordArray: [String]?
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func referenceCode(with exceptionHashlet: String? = nil) -> String {
        guard let words = getWordArray() else { return "" }
        
        let randomWord = words[numericCast(arc4random_uniform(numericCast(words.count)))].lowercased()
        let dateReference = dateHashlet()
        
        var fileName = "\(randomWord)-\(dateReference)"
        if let hashlet = exceptionHashlet {
            fileName = "\(hashlet.lowercased())-\(randomWord)-\(dateReference)"
        }
        
        return fileName
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private static func dateHashlet() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        dateFormatter.locale = Locale(identifier: "en_GB")
        
        var dateHash = dateFormatter.string(from: Date())
        
        let compressedData = try? (Data(dateHash.utf8) as NSData).compressed(using: .lzfse)
        if let data = compressedData {
            dateHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        } else {
            dateHash = SHA256.hash(data: Data(dateHash.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        let count = dateHash.characterArray.count
        let prefix = dateHash.characterArray[0...1]
        let suffix = dateHash.characterArray[count - 2...count - 1]
        
        return "\(prefix.joined())\(suffix.joined())".lowercased()
    }
    
    private static func getWordArray() -> [String]? {
        guard wordArray == nil else { return wordArray! }
        
        guard let path = Bundle.main.path(forResource: "words", ofType: "txt") else { return nil }
        
        do {
            let wordsString = try String(contentsOfFile: path)
            let components = wordsString.components(separatedBy: .newlines)
            wordArray = components
            
            return wordArray!
        } catch { return nil }
    }
}
