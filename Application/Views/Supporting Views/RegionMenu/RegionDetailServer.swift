//
//  RegionDetailServer.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 27/09/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

public enum RegionDetailServer {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Dictionaries
    private static var localizedRegionStringsForRegionCodes = [String: String]()
    private static var imagesForRegionCodes = [String: UIImage]()
    private static var imagesForRegionTitles = [String: UIImage]()
    private static var titlesForCallingCodes = [String: String]()
    private static var titlesForRegionCodes = [String: String]()
    
    // Other
    public enum RegionType {
        case regionCode
        case regionTitle
    }
    
    private static var regionTitles: [String]?
    
    //==================================================//
    
    /* MARK: - Calling Codes */
    
    public static func getCallingCode(forRegion: String) -> String? {
        guard let callingCode = RuntimeStorage.callingCodeDictionary![forRegion.uppercased()] else { return nil }
        
        return callingCode
    }
    
    //==================================================//
    
    /* MARK: - Images */
    
    public static func getImage(for: RegionType, with: String) -> UIImage? {
        guard imagesForRegionCodes[with] == nil else {
            return imagesForRegionCodes[with]
        }
        
        guard imagesForRegionTitles[with] == nil else {
            return imagesForRegionTitles[with]
        }
        
        let keys = Array(RuntimeStorage.callingCodeDictionary!.keys)
        let matches = `for` == .regionCode ? keys.filter({ $0 == with }) : keys.filter({ getRegionTitle(forRegionCode: $0) == with })
        
        guard matches.count > 0 else { return nil }
        
        guard let image = UIImage(named: "\(matches.first!.lowercased()).png") else { return nil }
        
        if `for` == .regionCode {
            imagesForRegionCodes[with] = image
        } else {
            imagesForRegionTitles[with] = image
        }
        
        return image
    }
    
    //==================================================//
    
    /* MARK: - Region Codes */
    
    public static func getRegionCode(forCallingCode: String) -> String {
        guard Array(RuntimeStorage.callingCodeDictionary!.values).contains(forCallingCode) else {
            return ""
        }
        
        let regions = RuntimeStorage.callingCodeDictionary!.allKeys(forValue: forCallingCode)
        
        guard regions.count == 1 else {
            return "multiple"
        }
        
        return regions[0]
    }
    
    public static func getRegionCode(forRegionTitle: String) -> String? {
        let matches = Array(RuntimeStorage.callingCodeDictionary!.keys).filter({ getRegionTitle(forRegionCode: $0) == forRegionTitle })
        
        guard matches.count > 0 else { return nil }
        
        return matches.first!
    }
    
    public static func randomRegionCode() -> String {
        guard let randomLanguageCode = RuntimeStorage.languageCodeDictionary!.keys.randomElement(),
              getCallingCode(forRegion: randomLanguageCode) != nil else {
            return randomRegionCode()
        }
        
        return randomLanguageCode
    }
    
    //==================================================//
    
    /* MARK: - Region Titles */
    
    public static func getLocalizedRegionString(forRegionCode: String) -> String {
        guard localizedRegionStringsForRegionCodes[forRegionCode] == nil else {
            return localizedRegionStringsForRegionCodes[forRegionCode]!
        }
        
        guard RuntimeStorage.callingCodeDictionary![forRegionCode] != nil else {
            return ""
        }
        
        let currentLocale = Locale(identifier: RuntimeStorage.languageCode!)
        let regionName = currentLocale.localizedString(forRegionCode: forRegionCode)
        
        guard let name = regionName else {
            localizedRegionStringsForRegionCodes[forRegionCode] = "Multiple"
            return localizedRegionStringsForRegionCodes[forRegionCode]!
        }
        
        localizedRegionStringsForRegionCodes[forRegionCode] = name
        return localizedRegionStringsForRegionCodes[forRegionCode]!
    }
    
    public static func getRegionTitle(forCallingCode: String) -> String {
        guard titlesForCallingCodes[forCallingCode] == nil else {
            return titlesForCallingCodes[forCallingCode]!
        }
        
        guard Array(RuntimeStorage.callingCodeDictionary!.values).contains(forCallingCode) else {
            return ""
        }
        
        let regions = RuntimeStorage.callingCodeDictionary!.allKeys(forValue: forCallingCode)
        
        guard regions.count == 1 else {
            titlesForCallingCodes[forCallingCode] = "+\(forCallingCode) (Multiple)"
            return titlesForCallingCodes[forCallingCode]!
        }
        
        titlesForCallingCodes[forCallingCode] = getRegionTitle(forRegionCode: regions[0])
        return titlesForCallingCodes[forCallingCode]!
    }
    
    public static func getRegionTitle(forRegionCode: String,
                                      menuFormatted: Bool? = nil) -> String {
        let menuFormatted = menuFormatted ?? false
        
        guard titlesForRegionCodes[forRegionCode] == nil else { return titlesForRegionCodes[forRegionCode]! }
        
        guard let callingCodes = RuntimeStorage.callingCodeDictionary,
              let callingCode = callingCodes[forRegionCode] else { return forRegionCode.uppercased() }
        
        let currentLocale = Locale(identifier: RuntimeStorage.languageCode!)
        let regionName = currentLocale.localizedString(forRegionCode: forRegionCode)
        
        guard let name = regionName else {
            if menuFormatted {
                titlesForRegionCodes[forRegionCode] = "(\(LocalizedString.multiple)) (+\(callingCode))"
            } else {
                titlesForRegionCodes[forRegionCode] = "+\(callingCode) (\(LocalizedString.multiple))"
            }
            
            return titlesForRegionCodes[forRegionCode]!
        }
        
        if menuFormatted {
            titlesForRegionCodes[forRegionCode] = "\(name) (+\(callingCode))"
        } else {
            titlesForRegionCodes[forRegionCode] = "+\(callingCode) (\(name))"
        }
        
        return titlesForRegionCodes[forRegionCode]!
    }
    
    public static func regionTitleArray() -> [String] {
        guard regionTitles == nil else {
            return regionTitles!
        }
        
        var titleArray = [String]()
        
        for key in RuntimeStorage.callingCodeDictionary!.keys {
            titleArray.append(getRegionTitle(forRegionCode: key, menuFormatted: true))
        }
        
        regionTitles = titleArray.sorted()
        return regionTitles!
    }
    
    //==================================================//
    
    /* MARK: - Other Methods */
    
    public static func clearCache() {
        localizedRegionStringsForRegionCodes = [String: String]()
        imagesForRegionCodes = [String: UIImage]()
        imagesForRegionTitles = [String: UIImage]()
        titlesForCallingCodes = [String: String]()
        titlesForRegionCodes = [String: String]()
    }
}
