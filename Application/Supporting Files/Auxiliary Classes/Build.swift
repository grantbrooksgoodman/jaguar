//
//  Build.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct Build {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Booleans
    public static var isOnline: Bool { get { return getNetworkStatus() } }
    
    private(set) static var timebombActive = Bool()
    
    //Integers
    public static var buildNumber: Int { get { return getBuildNumber() } }
    
    private static var appStoreReleaseVersion = Int()
    
    //Strings
    public static var buildSKU: String { get { return getBuildSKU() } }
    public static var bundleVersion: String { get { return getBundleVersion() } }
    public static var expiryInfoString: String { get { return getExpiryInfoString() } }
    public static var projectID: String { get { return getProjectID() } }
    
    private(set) static var codeName = String()
    private(set) static var finalName = String()
    
    private static var dmyFirstCompileDateString = String()
    
    //Other Declarations
    public static var expiryDate: Date { get { return getExpiryDate() } }
    
    private(set) static var stage: Stage!
    
    private static var buildDateUnixDouble: TimeInterval {
        get {
            let cfBuildDate = Bundle.main.infoDictionary!["CFBuildDate"] as! String
            
            return TimeInterval((cfBuildDate == "443750400" ? String(Date().timeIntervalSince1970).components(separatedBy: ".")[0] : cfBuildDate))!
        }
    }
    
    //==================================================//
    
    /* MARK: - Enumerated Type Declarations */
    
    public enum Metadatum {
        case appStoreReleaseVersion
        case codeName
        case dmyFirstCompileDateString
        case finalName
        case stage
        case timebombActive
    }
    
    public enum Stage: String {
        case preAlpha         /* Typically builds 0-1500 */
        case alpha            /* Typically builds 1500-3000 */
        case beta             /* Typically builds 3000-6000 */
        case releaseCandidate /* Typically builds 6000 onwards */
        case generalRelease
        
        public func description(short: Bool) -> String {
            switch self {
            case .preAlpha:
                return short ? "p" : "pre-alpha"
            case .alpha:
                return short ? "a" : "alpha"
            case .beta:
                return short ? "b" : "beta"
            case .releaseCandidate:
                return short ? "c" : "release candidate"
            default:
                return short ? "g" : "general"
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Setter Functions */
    
    public static func set(_ metadata: [Metadatum: Any]) {
        for key in Array(metadata.keys) {
            set(key, to: metadata[key]!)
        }
    }
    
    public static func set(_ metadata: Metadatum, to: Any) {
        switch metadata {
        case .appStoreReleaseVersion:
            guard let value = to as? Int else { fatalError("Wrong type passed") }
            appStoreReleaseVersion = value
        case .codeName:
            guard let value = to as? String else { fatalError("Wrong type passed") }
            codeName = value
        case .dmyFirstCompileDateString:
            guard let value = to as? String else { fatalError("Wrong type passed") }
            dmyFirstCompileDateString = value
        case .finalName:
            guard let value = to as? String else { fatalError("Wrong type passed") }
            finalName = value
        case .timebombActive:
            guard let value = to as? Bool else { fatalError("Wrong type passed") }
            timebombActive = value
        case .stage:
            guard let value = to as? Stage else { fatalError("Wrong type passed") }
            stage = value
        }
    }
    
    //==================================================//
    
    /* MARK: - Getter Functions */
    
    private static func getBuildNumber() -> Int {
        return Int(Bundle.main.infoDictionary!["CFBundleVersion"] as! String)!
    }
    
    private static func getBundleVersion() -> String {
        let currentReleaseBuildNumber = Int(Bundle.main.infoDictionary!["CFBundleReleaseVersion"] as! String)!
        
        return "\(String(appStoreReleaseVersion)).\(String(currentReleaseBuildNumber / 150)).\(String(currentReleaseBuildNumber / 50))"
    }
    
    private static func getBuildSKU() -> String {
        let buildNumber = Int(Bundle.main.infoDictionary!["CFBundleVersion"] as! String)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ddMMyy"
        
        let formattedBuildDateString = dateFormatter.string(from: Date(timeIntervalSince1970: buildDateUnixDouble))
        
        let threeLetterCodeNameIdentifier = (Build.codeName.count > 3 ? "\(String(Build.codeName.first!))\(String(Build.codeName[Build.codeName.index(Build.codeName.startIndex, offsetBy: Int((Double(Build.codeName.count) / 2).rounded(.down)))]))\(String(Build.codeName.last!))".uppercased() : Build.codeName.uppercased())
        
        return "\(formattedBuildDateString)-\(threeLetterCodeNameIdentifier)-\(String(format: "%06d", buildNumber))\(Build.stage.description(short: true))"
    }
    
    private static func getExpiryDate() -> Date {
        return Calendar.current.date(byAdding: .day,
                                     value: 30,
                                     to: Date(timeIntervalSince1970: buildDateUnixDouble).comparator)!.comparator
    }
    
    private static func getExpiryInfoString() -> String {
        let expiryDate = getExpiryDate()
        
        let expiryDateFormatter = DateFormatter()
        expiryDateFormatter.dateFormat = "dd-MM-yyyy"
        
        let daysUntilExpiry = Calendar.current.dateComponents([.day],
                                                              from: Date().comparator,
                                                              to: expiryDate.comparator).day!
        
        var expiryInfoString = "The evaluation period for this build will expire on \(expiryDateFormatter.string(from: expiryDate)). After this date, the entry of a six-digit expiration override code will be required to continue using this software. It is strongly encouraged that the build be updated before the end of the evaluation period."
        
        //Date() <= expiryDate ???
        expiryInfoString = daysUntilExpiry <= 0 ? "The evaluation period for this build ended on \(expiryDateFormatter.string(from: expiryDate))." : expiryInfoString
        
        return expiryInfoString
    }
    
    private static func getNetworkStatus() -> Bool {
        let connectionReachability = try! Reachability()
        let networkStatus = connectionReachability.connection.description
        
        return (networkStatus != "No Connection")
    }
    
    private static func getProjectID() -> String {
        let identifierDateFormatter = DateFormatter()
        identifierDateFormatter.dateFormat = "ddMMyyyy"
        
        let firstCompileDate = identifierDateFormatter.date(from: dmyFirstCompileDateString) ?? identifierDateFormatter.date(from: "24011984")!
        
        let codeNameFirstLetterPositionValue = String(Build.codeName.first!).alphabeticalPosition
        let codeNameLastLetterPositionValue = String(Build.codeName.last!).alphabeticalPosition
        
        let dateComponents = Calendar.current.dateComponents([.day, .month, .year],
                                                             from: firstCompileDate)
        
        let offset = Int((Double(Build.codeName.count) / 2).rounded(.down))
        let middleLetterIndex = Build.codeName.index(Build.codeName.startIndex, offsetBy: offset)
        let middleLetter = String(Build.codeName[middleLetterIndex])
        
        let multipliedConstants = String(codeNameFirstLetterPositionValue * middleLetter.alphabeticalPosition * codeNameLastLetterPositionValue * dateComponents.day! * dateComponents.month! * dateComponents.year!).map({ String($0) })
        
        var projectIdComponents = [String]()
        
        for integerString in multipliedConstants {
            projectIdComponents.append(integerString)
            
            let cipheredMiddleLetter = middleLetter.ciphered(by: Int(integerString)!).uppercased()
            projectIdComponents.append(cipheredMiddleLetter)
        }
        
        projectIdComponents = Array(NSOrderedSet(array: projectIdComponents)) as! [String]
        
        if projectIdComponents.count > 8 {
            while projectIdComponents.count > 8 {
                projectIdComponents.removeLast()
            }
        } else if projectIdComponents.count < 8 {
            var currentLetter = middleLetter
            
            while projectIdComponents.count < 8 {
                currentLetter = currentLetter.ciphered(by: currentLetter.alphabeticalPosition)
                
                if !projectIdComponents.contains(currentLetter) {
                    projectIdComponents.append(currentLetter)
                }
            }
        }
        
        return (Array(NSOrderedSet(array: projectIdComponents)) as! [String]).joined()
    }
}

