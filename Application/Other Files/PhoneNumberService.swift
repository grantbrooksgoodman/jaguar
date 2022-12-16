//
//  PhoneNumberService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 28/09/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import PhoneNumberKit

public enum PhoneNumberService {
    
    //==================================================//
    
    /* MARK: - Calling Codes */
    
    private static func backformedCallingCodes(forNumber: String) -> [String] {
        var candidates = [String]()
        
#warning("Will have different keys every time for each one with duplicates.")
        guard let callingCodes = RuntimeStorage.callingCodeDictionary else { return candidates }
        
        let uniqueCallingCodeDictionary = callingCodes.uniqueValues()
        
        for region in Array(uniqueCallingCodeDictionary.keys) {
            let callingCode = uniqueCallingCodeDictionary[region]!.digits
            
            if numberMatchesPattern(forNumber,
                                    forRegionPair: (region, callingCode)) {
                candidates.append(callingCode)
            }
        }
        
        return candidates
    }
    
    private static func extractCallingCodes(fromNumber: String) -> [String] {
        let prependedUnformattedNumber = "+\(fromNumber)"
        let prependedFormattedNumber = "+\(fromNumber.digits)"
        
        let phoneNumberKit = PhoneNumberKit()
        var callingCodes = [String]()
        
        guard let callingCodeDictionary = RuntimeStorage.callingCodeDictionary else { return callingCodes }
        
        do {
            let unformattedParsed = try phoneNumberKit.parse(prependedUnformattedNumber)
            let formattedParsed = try phoneNumberKit.parse(prependedFormattedNumber)
            
            if let unformattedRegionCode = phoneNumberKit.getRegionCode(of: unformattedParsed),
               let callingCode = callingCodeDictionary[unformattedRegionCode.uppercased()] {
                callingCodes.append(callingCode)
            } else if let formattedRegionCode = phoneNumberKit.getRegionCode(of: formattedParsed),
                      let callingCode = callingCodeDictionary[formattedRegionCode.uppercased()] {
                callingCodes.append(callingCode)
            }
        } catch _ { }
        
        return callingCodes
    }
    
    public static func possibleCallingCodes(forNumber: String) -> [String] {
        var candidates = [String]()
        
        guard let lookupTables = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "LookupTables", ofType: "plist") ?? "") as? [String: [String]] else { return candidates }
        
        for possibleRawNumber in forNumber.possibleRawNumbers() {
            guard let possibleCodes = lookupTables[String(possibleRawNumber.count)] else { continue }
            candidates.append(contentsOf: possibleCodes)
        }
        
        //        candidates.append(contentsOf: backformedCallingCodes(forNumber: forNumber))
        //        candidates.append(contentsOf: extractCallingCodes(fromNumber: forNumber))
        
        return candidates.unique()
    }
    
    //==================================================//
    
    /* MARK: - Hashing */
    
    public static func possibleHashes(forNumber: String) -> [String] {
        let digits = forNumber.digits
        var candidates = [digits.compressedHash]
        
        for dropCount in 1...3 {
            let droppedNumber = digits.dropPrefix(dropCount)
            
            candidates.append(droppedNumber.compressedHash)
        }
        
        return candidates
    }
    
    public static func possibleHashes(forNumbers: [String]) -> [String] {
        var candidates = [String]()
        
        for number in forNumbers {
            candidates.append(contentsOf: possibleHashes(forNumber: number))
        }
        
        return candidates
    }
    
    //==================================================//
    
    /* MARK: - Lookup Table Generation */
    
    private static func generateLookupTables() -> [String: [String]] {
        let digitCounts = [4, 5, 6, 7, 8, 9, 10, 11]
        var lookupTable = [String: [String]]()
        
        for count in digitCounts {
            let generatedTable = generateLookupTable(for: count)
            
            guard !generatedTable.isEmpty else { continue }
            
            let values = Array(lookupTable.values)
            var merged = [String]()
            
            for value in values {
                merged.append(contentsOf: value)
            }
            
            lookupTable[String(count)] = generatedTable
        }
        
        let filePath = PLISTGenerator.createPLIST(from: lookupTable)
        guard let path = filePath else {
            Logger.log(Exception("Failed to generate PLIST.",
                                 metadata: [#file, #function, #line]))
            return lookupTable
        }
        
        Logger.log("Created PLIST at path:\n\(path)",
                   metadata: [#file, #function, #line])
        return lookupTable
    }
    
    private static func generateLookupTable(for digitCount: Int) -> [String] {
        var candidates = [String]()
        
        guard let callingCodes = RuntimeStorage.callingCodeDictionary else { return candidates }
        
        let uniqueCallingCodeDictionary = callingCodes.uniqueValues()
        let randomNumber = randomPhoneNumber(digits: digitCount)
        
        for region in Array(uniqueCallingCodeDictionary.keys) {
            let callingCode = uniqueCallingCodeDictionary[region]!.digits
            
            if numberMatchesPattern(randomNumber,
                                    forRegionPair: (region, callingCode)) {
                candidates.append(callingCode)
            }
        }
        
        return candidates
    }
    
    //==================================================//
    
    /* MARK: - Pattern Matching */
    
    private static func isPossibleAmericanNumber(_ number: String) -> Bool {
        let digits = number.digits
        
        if (digits.hasPrefix("1") && digits.count == 11) || digits.count == 10 {
            return true
        }
        
        return false
    }
    
    private static func numberMatchesPattern(_ number: String,
                                             forRegionPair: (key: String,
                                                             value: String)) -> Bool {
        let phoneNumberKit = PhoneNumberKit()
        
        let region = forRegionPair.key
        let callingCode = forRegionPair.value.digits
        
        guard let regionMetadata = phoneNumberKit.metadata(for: region),
              let description = regionMetadata.mobile,
              let exampleNumber = description.exampleNumber else { return false }
        
        let bareNumber = number.digits
        let bareExample = exampleNumber.digits
        
        let prependedExample = "\(callingCode)\(bareExample)"
        let prependedNumber = "\(callingCode)\(bareNumber)"
        
        if bareExample.count == bareNumber.count {
            return true
        } else if prependedExample.count == prependedNumber.count {
            return true
        } else if bareNumber.hasPrefix(callingCode) {
            let droppedPrefix = bareNumber.dropPrefix(callingCode.count)
            if droppedPrefix.count == bareExample.count {
                return true
            }
        }
        
        return false
    }
    
    //==================================================//
    
    /* MARK: - Other */
    
    private static func randomPhoneNumber(digits: Int) -> String {
        var phoneNumber = ""
        
        guard digits - 1 > 0 else { return phoneNumber }
        
        for _ in 0...digits - 1 {
            phoneNumber += String(Int().random(min: 0, max: 9))
        }
        
        return phoneNumber
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Dictionary */
public extension Dictionary where Key == String, Value == String {
    func uniqueValues() -> [String: String] {
        var uniqueValues = Set<String>()
        var result = [String: String](minimumCapacity: self.count)
        
        for (key, value) in self.sorted(by: { $0.key < $1.key }) {
            if !uniqueValues.contains(value) {
                uniqueValues.insert(value)
                result[key] = value
            }
        }
        
        return result
    }
}

/* MARK: String */
public extension String {
    func possibleRawNumbers() -> [String] {
        var candidates = [self.digits]
        
        guard self.count > 3 else { return [] }
        
        for dropCount in 1...3 {
            let droppedNumber = self.digits.dropPrefix(dropCount)
            candidates.append(droppedNumber)
        }
        
        return candidates
    }
}
