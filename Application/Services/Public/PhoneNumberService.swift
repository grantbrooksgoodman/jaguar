//
//  PhoneNumberService.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Contacts
import Foundation

/* Third-party Frameworks */
import FirebaseAuth
import PhoneNumberKit

public struct PhoneNumberService {
    
    //==================================================//
    
    /* MARK: - Calling Code Determination */
    
    /* ONLY use this function when you've already exhausted possibilities
     that it's prefixed to the number*/
    private static func callingCodes(for number: String) -> [String]? {
        guard let lookupTables = RuntimeStorage.lookupTableDictionary,
              let callingCodesForNumberLength = lookupTables[String(number.count)] else { return nil }
        
        return callingCodesForNumberLength
    }
    
    public static func containsCallingCode(number: String) -> Bool {
        return matchingCountryCodes(for: number) != nil
    }
    
    // For numbers WITH a calling code already
    /* THIS FUNCTION WILL ONLY WORK WHEN THE NUMBER HAS A CALLING CODE */
    /// Determines if the provided number's prefix matches any country codes.
    private static func matchingCountryCodes(for number: String) -> [String]? {
        guard let dictionary = RuntimeStorage.callingCodeDictionary,
              let lookupTables = RuntimeStorage.lookupTableDictionary else { return nil }
        
        let callingCodes = dictionary.values
        var matches = [String]()
        
        for code in Array(callingCodes).unique() {
            guard number.hasPrefix(code) else { continue }
            
            let rawNumberLengthString = String(number.dropPrefix(code.count).count)
            guard let callingCodesForNumberLength = lookupTables[rawNumberLengthString],
                  callingCodesForNumberLength.contains(code) else { continue }
            
            /* This number has a prefix that matches a country code, and excluding it
             results in a length that matches that country's phone numbers. */
            matches.append(code)
        }
        
        return matches.isEmpty ? nil : matches
    }
    
    public static func possibleCallingCodes(for number: String) -> [String]? {
        guard containsCallingCode(number: number) else {
            /* Now we KNOW there's no calling code prefixed to this number.
             This means there's no reason for us to chop the string */
            return callingCodes(for: number)
        }
        
        return matchingCountryCodes(for: number)
    }
    
    //==================================================//
    
    /* MARK: - Hash Generation */
    
    public static func possibleHashes(for number: String) -> [String]? {
        var hashes = [String]()
        
        if containsCallingCode(number: number) {
            guard let countryCodes = matchingCountryCodes(for: number) else { return nil }
            for code in countryCodes {
                hashes.append(number.dropPrefix(code.count).compressedHash)
            }
        } else {
            hashes.append(number.compressedHash)
        }
        
        return hashes.isEmpty ? nil : hashes
    }
    
    public static func possibleHashes(for numbers: [String]) -> [String] {
        var hashes = [String]()
        
        for number in numbers {
            guard let candidates = possibleHashes(for: number) else { continue }
            hashes.append(contentsOf: candidates)
        }
        
        return hashes
    }
    
    //==================================================//
    
    /* MARK: - Phone Number Formatting */
    
    public static func failsafeFormat(_ number: String) -> String {
        let digits = number.digits
        let evenDigits = digits.count % 2 == 0
        
        var formattedString = ""
        for (index, character) in digits.characterArray.enumerated() {
            guard index != 0 else {
                formattedString = character
                continue
            }
            
            guard index % 2 == 0 else {
                formattedString = "\(formattedString)\(evenDigits ? "" : " ")\(character)"
                continue
            }
            
            formattedString = "\(formattedString)\(evenDigits ? " " : "")\(character)"
        }
        
        return formattedString.trimmingBorderedWhitespace
    }
    
    public static func format(_ number: String) -> String {
        let digits = number.digits
        let fallbackFormatted = failsafeFormat(digits)
        
        guard containsCallingCode(number: digits),
              let callingCodes = matchingCountryCodes(for: digits),
              callingCodes.count == 1 else { return fallbackFormatted }
        
        let callingCode = callingCodes[0]
        
        guard callingCode != "1" else {
            guard let formatted = CNPhoneNumber(stringValue: digits).value(forKey: "formattedInternationalStringValue") as? String else { return fallbackFormatted }
            return formatted
        }
        
        let regionCode = RegionDetailServer.getRegionCode(forCallingCode: callingCode)
        
        let phoneNumberKit = PhoneNumberKit()
        let formattedNumber: String?
        
        do {
            let parsed = try phoneNumberKit.parse(number.digits, withRegion: regionCode)
            formattedNumber = phoneNumberKit.format(parsed, toType: .international)
        } catch { return fallbackFormatted }
        
        return formattedNumber ?? fallbackFormatted
    }
    
    //==================================================//
    
    /* MARK: - User Verification */
    
    private static func verifyPhoneNumber(_ string: String,
                                          completion: @escaping (_ identifier: String?,
                                                                 _ exception: Exception?) -> Void) {
        Auth.auth().languageCode = RuntimeStorage.languageCode!
        PhoneAuthProvider.provider().verifyPhoneNumber(string,
                                                       uiDelegate: nil) { (identifier,
                                                                           error) in
            completion(identifier, error == nil ? nil : Exception(error!, metadata: [#file, #function, #line]))
        }
    }
    
    public static func verifyUser(phoneNumber: PhoneNumber,
                                  completion: @escaping (_ identifier: String?,
                                                         _ exception: Exception?,
                                                         _ hasAccount: Bool) -> Void) {
        UserSerializer.shared.findUsers(for: phoneNumber.digits) { users, exception in
            guard users == nil || users?.count == 0 else {
                completion(nil, nil, true)
                return
            }
            
            self.verifyPhoneNumber("+\(phoneNumber.digits!)") { identifier, exception in
                guard let identifier else {
                    completion(nil, exception ?? Exception(metadata: [#file, #function, #line]), false)
                    return
                }
                
                completion(identifier, nil, false)
            }
        }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: String */
public extension String {
    
    /* MARK: - Methods */
    
    func partiallyFormatted(for region: String) -> String {
        guard digits != "" else { return self }
        
        var fullFormatAttempt = PhoneNumberService.format(self)
        guard let callingCode = RegionDetailServer.getCallingCode(forRegion: region) else { return fullFormatAttempt }
        
        guard fullFormatAttempt == PhoneNumberService.failsafeFormat(self) else {
            guard fullFormatAttempt.hasPrefix("+\(callingCode)") else {
                let partialFormatter = PartialFormatter(defaultRegion: region.uppercased(), withPrefix: true)
                return partialFormatter.formatPartial(digits)
            }
            
            fullFormatAttempt = fullFormatAttempt.removingOccurrences(of: ["+"])
            fullFormatAttempt = fullFormatAttempt.dropPrefix(callingCode.count)
            
            return fullFormatAttempt.trimmingBorderedWhitespace
        }
        
        let partialFormatter = PartialFormatter(defaultRegion: region.uppercased(), withPrefix: true)
        return partialFormatter.formatPartial(digits)
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var phoneNumberFormatted: String {
        guard digits != "" else { return self }
        return PhoneNumberService.format(self)
    }
}
