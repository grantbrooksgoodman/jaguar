//
//  RecognitionService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 18/12/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit
import NaturalLanguage
import Translator

public struct RecognitionService {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private static var detectionCache = [String: String]()
    private static var translationCache = [String: (pair: LanguagePair, untranslated: Bool)]()
    
    //==================================================//
    
    /* MARK: - Public Methods */
    
    public static func clearCache() {
        detectionCache = [:]
        translationCache = [:]
    }
    
    public static func detectedLanguage(for string: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(string)
        
        guard let languageCode = recognizer.dominantLanguage?.rawValue else { return nil }
        
        detectionCache[string] = languageCode
        return languageCode
    }
    
    public static func shouldMarkUntranslated(_ string: String,
                                              for pair: LanguagePair) -> Bool {
        guard !translationCache.contains(where: { $0.key == string && $0.value.pair.asString() == pair.asString() }) else { return translationCache[string]!.untranslated }
        
        guard detectedLanguage(for: string) != pair.to else {
            translationCache[string] = (pair: pair, untranslated: false)
            return false
        }
        
        guard string.rangeOfCharacter(from: CharacterSet.letters) != nil,
              string.lowercasedTrimmingWhitespace.count > 1 else {
            translationCache[string] = (pair: pair, untranslated: false)
            return false
        }
        
        let fromPossibleWords = percentOfPossibleWords(in: string, language: pair.from)
        let toPossibleWords = percentOfPossibleWords(in: string, language: pair.to)
        
        //        print("% of possible \(pair.from) words in '\(string)': \(fromPossibleWords * 100)")
        //        print("% of possible \(pair.to) words in '\(string)': \(toPossibleWords * 100)")
        
        // #warning("Logic can be tweaked here.")
        if isConfidentlyOne(of: pair, string: string) || fromPossibleWords > 0.6 || toPossibleWords > 0.6 {
            translationCache[string] = (pair: pair, untranslated: true)
            return true
        }
        
        translationCache[string] = (pair: pair, untranslated: false)
        return false
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private static func isReal(word: String,
                               language code: String) -> Bool {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: code)
        
        return misspelledRange.location == NSNotFound
    }
    
    private static func isConfidentlyOne(of languagePair: LanguagePair,
                                         string: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(string)
        
        var hypotheses = recognizer.languageHypotheses(withMaximum: 5).sorted(by: { $0.value > $1.value })
        hypotheses = hypotheses.filter({ $0.key.rawValue.hasPrefix(languagePair.to) || $0.key.rawValue.hasPrefix(languagePair.from) })
        
        return hypotheses.count > 0
    }
    
    private static func percentOfPossibleWords(in sentence: String,
                                               language code: String) -> Float {
        let components = sentence.components(separatedBy: " ")
        guard !components.isEmpty else { return 0.0 }
        
        var possibleWords = 0
        for word in components where isReal(word: word, language: code) {
            possibleWords += 1
        }
        
        return Float(possibleWords)/Float(components.count)
    }
}
