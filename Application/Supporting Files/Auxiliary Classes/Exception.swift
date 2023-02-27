//
//  Exception.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import CryptoKit

/* Third-party Frameworks */
import AlertKit

public struct Exception: Equatable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Arrays
    private(set) var metadata: [Any]!
    private(set) var underlyingExceptions: [Exception]?
    
    // Strings
    private(set) var descriptor: String!
    private(set) var hashlet: String!
    private(set) var metaID: String!
    
    // Other
    private(set) var extraParams: [String: Any]?
    private(set) var isReportable: Bool!
    
    //==================================================//
    
    /* MARK: - Constructor Methods */
    
    public init(_ descriptor: String? = nil,
                isReportable: Bool? = nil,
                extraParams: [String: Any]? = nil,
                underlyingExceptions: [Exception]? = nil,
                metadata: [Any]) {
        guard validateMetadata(metadata) else { fatalError("Improperly formatted metadata") }
        
        self.descriptor = descriptor ?? "An unknown error occurred."
        self.isReportable = isReportable ?? true
        self.extraParams = extraParams
        self.metadata = metadata
        
        self.hashlet = getHashlet(for: self.descriptor)
        self.metaID = getMetaID(for: metadata)
        
        // #warning("Is the self filter necessary?")
        self.underlyingExceptions = underlyingExceptions?.unique().filter({ $0 != self })
    }
    
    public init(_ error: Error,
                isReportable: Bool? = nil,
                extraParams: [String: Any]? = nil,
                underlyingExceptions: [Exception]? = nil,
                metadata: [Any]) {
        self.init(error as NSError,
                  isReportable: isReportable,
                  extraParams: extraParams,
                  underlyingExceptions: underlyingExceptions,
                  metadata: metadata)
    }
    
    public init(_ error: NSError,
                isReportable: Bool? = nil,
                extraParams: [String: Any]? = nil,
                underlyingExceptions: [Exception]? = nil,
                metadata: [Any]) {
        guard validateMetadata(metadata) else { fatalError("Improperly formatted metadata") }
        
        self.descriptor = error.localizedDescription
        self.isReportable = isReportable ?? true
        self.metadata = metadata
        
        var params: [String: Any] = error.userInfo.filter({ $0.key != "NSLocalizedDescription" })
        params["NSErrorCode"] = error.code
        
        if let extraParams = extraParams,
           !extraParams.isEmpty {
            extraParams.forEach { param in
                if param.key != "NSLocalizedDescription" {
                    params[param.key] = param.value
                }
            }
        }
        
        self.extraParams = params.withCapitalizedKeys
        
        self.hashlet = getHashlet(for: self.descriptor)
        self.metaID = getMetaID(for: metadata)
        
        self.underlyingExceptions = underlyingExceptions?.unique().filter({ $0 != self })
    }
    
    //==================================================//
    
    /* MARK: - Appending Methods */
    
    public func appending(extraParams: [String: Any]) -> Exception {
        guard let currentParams = self.extraParams,
              !currentParams.isEmpty else {
            return Exception(self.descriptor,
                             isReportable: self.isReportable,
                             extraParams: extraParams.withCapitalizedKeys,
                             metadata: self.metadata)
        }
        
        var params: [String: Any] = currentParams
        extraParams.forEach { param in
            params[param.key] = param.value
        }
        
        return Exception(self.descriptor,
                         isReportable: self.isReportable,
                         extraParams: params.withCapitalizedKeys,
                         metadata: [#file, #function, #line])
    }
    
    public func appending(underlyingException: Exception) -> Exception {
        guard let currentUnderlyingExceptions = self.underlyingExceptions,
              !currentUnderlyingExceptions.isEmpty else {
            return Exception(self.descriptor,
                             isReportable: self.isReportable,
                             extraParams: self.extraParams,
                             underlyingExceptions: [underlyingException],
                             metadata: self.metadata)
        }
        
        var exceptions = currentUnderlyingExceptions
        exceptions.append(underlyingException)
        
        return Exception(self.descriptor,
                         isReportable: self.isReportable,
                         extraParams: self.extraParams,
                         underlyingExceptions: exceptions,
                         metadata: self.metadata)
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func getHashlet(for descriptor: String) -> String {
        var hashlet = ""
        
        let stripWords = ["a", "an", "is", "that", "the", "this", "was"]
        for word in descriptor.components(separatedBy: " ") {
            guard !stripWords.contains(word.lowercased()) else { continue }
            hashlet.append("\(word)\(word.lowercased() == "not" ? "" : " ")")
        }
        
        let alphabetSet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        hashlet = hashlet.filter({ alphabetSet.contains($0) })
        
        hashlet = hashlet.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
        
        let compressedData = try? (Data(hashlet.utf8) as NSData).compressed(using: .lzfse)
        if let data = compressedData {
            hashlet = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        } else {
            hashlet = SHA256.hash(data: Data(hashlet.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        let count = hashlet.characterArray.count
        let prefix = hashlet.characterArray[0...1]
        let suffix = hashlet.characterArray[count - 2...count - 1]
        
        return "\(prefix.joined())\(suffix.joined())".uppercased()
    }
    
    private func getMetaID(for metadata: [Any]) -> String {
        let unformattedFileName = metadata[0] as! String
        let fileName = unformattedFileName.components(separatedBy: "/").last!.components(separatedBy: ".")[0]
        
        let lineNumber = metadata[2] as! Int
        
        var hexArray: [String] = []
        
        for character in fileName.components(separatedBy: "Controller")[0] {
            hexArray.append(String(format: "%02X", character.asciiValue!))
        }
        
        if hexArray.count > 3 {
            var subsequence = Array(hexArray[0...1])
            subsequence.append(hexArray.last!)
            
            hexArray = subsequence
        }
        
        return "\(hexArray.joined(separator: ""))x\(lineNumber)".lowercased()
    }
    
    private func validateMetadata(_ metadata: [Any]) -> Bool {
        guard metadata.count == 3,
              metadata[0] is String,
              metadata[1] is String,
              metadata[2] is Int else {
            return false
        }
        
        return true
    }
    
    //==================================================//
    
    /* MARK: - Equatable Compliance Method */
    
    public static func == (lhs: Exception, rhs: Exception) -> Bool {
        let leftMetaID = lhs.metaID
        let leftHashlet = lhs.hashlet
        let leftDescriptor = lhs.descriptor
        let leftIsReportable = lhs.isReportable
        let leftUnderlyingExceptions = lhs.underlyingExceptions
        let leftAllUnderlyingExceptions = lhs.allUnderlyingExceptions()
        
        let rightMetaID = rhs.metaID
        let rightHashlet = rhs.hashlet
        let rightDescriptor = rhs.descriptor
        let rightIsReportable = rhs.isReportable
        let rightUnderlyingExceptions = rhs.underlyingExceptions
        let rightAllUnderlyingExceptions = rhs.allUnderlyingExceptions()
        
        var leftStringBasedParams = [String: String]()
        lhs.extraParams?.forEach({ parameter in
            if let stringValue = parameter.value as? String {
                leftStringBasedParams[parameter.key] = stringValue
            }
        })
        
        var rightStringBasedParams = [String: String]()
        rhs.extraParams?.forEach({ parameter in
            if let stringValue = parameter.value as? String {
                rightStringBasedParams[parameter.key] = stringValue
            }
        })
        
        let leftNonStringBasedParamsCount = (lhs.extraParams?.count ?? 0) - leftStringBasedParams.count
        let rightNonStringBasedParamsCount = (rhs.extraParams?.count ?? 0) - rightStringBasedParams.count
        
        guard leftMetaID == rightMetaID,
              leftHashlet == rightHashlet,
              leftDescriptor == rightDescriptor,
              leftIsReportable == rightIsReportable,
              leftUnderlyingExceptions == rightUnderlyingExceptions,
              leftAllUnderlyingExceptions == rightAllUnderlyingExceptions,
              leftStringBasedParams == rightStringBasedParams,
              leftNonStringBasedParamsCount == rightNonStringBasedParamsCount else { return false }
        
        return true
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - Array */
public extension Array where Element == Exception {
    /* MARK: - Methods */
    
    func unique() -> [Exception] {
        var uniqueValues = [Exception]()
        
        for value in self {
            if !uniqueValues.contains(where: { $0 == value }) {
                uniqueValues.append(value)
            }
        }
        
        return uniqueValues
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    /**
     Returns a single **Exception** from an array of **Exceptions** by appending each as underlying **Exceptions** to the final item in the array.
     */
    var compiledException: Exception? {
        //        return nil
        
        guard !isEmpty else { return nil }
        
        var finalException = last!
        
        guard count > 1 else { return finalException }
        
        Array(reversed()[1...count - 1]).unique().forEach { exception in
            finalException = finalException.appending(underlyingException: exception)
        }
        
        return finalException
    }
    
    /**
     Returns an array of identifier strings for each **Exception** in the array.
     */
    var referenceCodes: [String] {
        var codes = [String]()
        
        for (index, exception) in self.enumerated() {
            let suffix = codes.contains(where: { $0.hasPrefix(exception.hashlet!.lowercased()) }) ? "x\(index)" : ""
            codes.append("\(exception.hashlet!)x\(exception.metaID!)\(suffix)".lowercased())
            
            exception.allUnderlyingExceptions().enumerated().forEach { (index, underlyingException) in
                let suffix = codes.contains(where: { $0.hasPrefix(underlyingException.hashlet!.lowercased()) }) ? "x\(index)" : ""
                codes.append("\(underlyingException.hashlet!)x\(underlyingException.metaID!)\(suffix)".lowercased())
                
            }
        }
        
        return codes
    }
}

/* MARK: - Dictionary */
public extension Dictionary where Key == String, Value == Any {
    var withCapitalizedKeys: [String: Any] {
        var capitalized = [String: Any]()
        
        keys.forEach { key in
            capitalized[key.firstUppercase] = self[key]!
        }
        
        return capitalized
    }
}

/* MARK: - Exception */
public extension Exception {
    // #warning("This is better, but might still be wonky. Think about the recursion...")
    func allUnderlyingExceptions(_ with: [Exception]? = nil) -> [Exception] {
        var allExceptions = [Exception]()
        
        if let underlying = self.underlyingExceptions {
            allExceptions = underlying
            
            for exception in underlying {
                allExceptions.append(contentsOf: exception.allUnderlyingExceptions(allExceptions))
            }
        }
        
        return allExceptions.unique()
    }
    
    func asAkError() -> AKError {
        let descriptor = self.userFacingDescriptor
        
        var params: [String: Any] = ["Descriptor": self.descriptor!,
                                     "Hashlet": self.hashlet!]
        
        if let extraParams = extraParams,
           !extraParams.isEmpty {
            extraParams.forEach { param in
                params[param.key] = param.value
            }
        }
        
        if let underlyingExceptions = underlyingExceptions,
           !underlyingExceptions.isEmpty {
            params["UnderlyingExceptions"] = underlyingExceptions.referenceCodes
        }
        
        return AKError(descriptor,
                       isReportable: self.isReportable,
                       extraParams: params.withCapitalizedKeys,
                       metadata: self.metadata)
    }
    
    func isEqual(to cataloggedException: JRException) -> Bool {
        return hashlet == cataloggedException.description
    }
    
    func isEqual(toAny in: [JRException]) -> Bool {
        for exception in `in` {
            guard hashlet == exception.description else { continue }
            return true
        }
        
        return false
    }
}
