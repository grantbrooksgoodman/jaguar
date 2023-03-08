//
//  SentenceGenerator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public enum SentenceGenerator {
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func getWords(count: Int) -> String {
        guard count > 0 else { return "" }
        
        guard let words = getWords() else {
            Logger.log(Exception("Couldn't get words.", metadata: [#file, #function, #line]))
            return ""
        }
        
        var generatedWords = [String]()
        for _ in 1...count {
            generatedWords.append(words[numericCast(arc4random_uniform(numericCast(words.count)))])
        }
        
        return generatedWords.joined(separator: "-")
    }
    
    public static func generateSentence(wordCount: Int) -> String {
        guard let words = getWords() else {
            Logger.log("Couldn't get words.",
                       metadata: [#file, #function, #line])
            return "" //bad
        }
        
        var sentenceString = ""
        var periodIndices = [Int]()
        
        for index in 0...wordCount {
            var randomWord = words[numericCast(arc4random_uniform(numericCast(words.count)))]
            
            if randomWord.hasPrefix(anyIn: randomString(of: 10).characterArray) {
                randomWord = "\(randomWord),"
            } else if randomWord.hasPrefix(anyIn: randomString(of: 6).characterArray) {
                let character = [".", "?", "!", "?!"].randomElement
                randomWord = "\(randomWord)\(character)"
                periodIndices.append(index + 1)
            }
            
            if periodIndices.contains(index) {
                randomWord = randomWord.capitalized
            }
            
            let leftSpace = index == 0 || index == 1 ? "" : " "
            let rightSpace = index == 0 ? " " : ""
            
            sentenceString += "\(leftSpace)\(randomWord)\(rightSpace)"
        }
        
        return sentenceString.firstUppercase + "."
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private static func getWords() -> [String]? {
        guard let path = Bundle.main.path(forResource: "words", ofType: "txt") else {
            Logger.log("Words file does not exist!",
                       metadata: [#file, #function, #line])
            return nil
        }
        
        do {
            let wordsString = try String(contentsOfFile: path)
            
            return wordsString.components(separatedBy: .newlines)
        } catch {
            Logger.log(error,
                       metadata: [#file, #function, #line])
            return nil
        }
    }
    
    private static func randomString(of length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var s = ""
        for _ in 0 ..< length {
            s.append(letters.randomElement()!)
        }
        return s
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - String */
private extension String {
    func hasPrefix(anyIn: [String]) -> Bool {
        for string in anyIn {
            if self.hasPrefix(string) {
                return true
            }
        }
        
        return false
    }
}
