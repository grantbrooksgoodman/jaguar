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
    
    /* MARK: - Enums */
    
    public enum RegionType {
        case regionCode
        case regionTitle
    }
    
    //==================================================//
    
    /* MARK: - Calling Codes */
    
    public static func getCallingCode(forRegion: String) -> String? {
        guard let callingCode = RuntimeStorage.callingCodeDictionary![forRegion.uppercased()] else { return nil }
        
        return callingCode
    }
    
    //==================================================//
    
    /* MARK: - Images */
    
    public static func getImage(for: RegionType, with: String) -> UIImage? {
        let keys = Array(RuntimeStorage.callingCodeDictionary!.keys)
        let matches = `for` == .regionCode ? keys.filter({ $0 == with }) : keys.filter({ getRegionTitle(forRegionCode: $0) == with })
        
        guard matches.count > 0 else { return nil }
        
        guard let image = UIImage(named: "\(matches.first!.lowercased()).png") else { return nil }
        
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
        guard RuntimeStorage.callingCodeDictionary![forRegionCode] != nil else {
            return ""
        }
        
        let currentLocale = Locale(identifier: RuntimeStorage.languageCode!)
        let regionName = currentLocale.localizedString(forRegionCode: forRegionCode)
        
        guard let name = regionName else {
            return "Multiple"
        }
        
        return name
    }
    
    public static func getRegionTitle(forCallingCode: String) -> String {
        guard Array(RuntimeStorage.callingCodeDictionary!.values).contains(forCallingCode) else {
            return ""
        }
        
        let regions = RuntimeStorage.callingCodeDictionary!.allKeys(forValue: forCallingCode)
        
        guard regions.count == 1 else {
            return "+\(forCallingCode) (Multiple)"
        }
        
        return getRegionTitle(forRegionCode: regions[0])
    }
    
    private static func getRegionTitle(forRegionCode: String) -> String {
        guard RuntimeStorage.callingCodeDictionary![forRegionCode] != nil else {
            return ""
        }
        
        let currentLocale = Locale(identifier: RuntimeStorage.languageCode!)
        let regionName = currentLocale.localizedString(forRegionCode: forRegionCode)
        
        guard let name = regionName else {
            return "+\(RuntimeStorage.callingCodeDictionary![forRegionCode]!) (Multiple)"
        }
        
        return "+\(RuntimeStorage.callingCodeDictionary![forRegionCode]!) (\(name))"
    }
    
    public static func regionTitleArray() -> [String] {
        var titleArray = [String]()
        
        for key in RuntimeStorage.callingCodeDictionary!.keys {
            titleArray.append(getRegionTitle(forRegionCode: key))
        }
        
        return titleArray.sorted()
    }
}
