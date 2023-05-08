//
//  Contact.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import ContactsUI

public struct Contact: Codable, Equatable, Identifiable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Arrays
    public var phoneNumbers: [PhoneNumber]
    
    // Strings
    public var firstName: String
    public var lastName: String
    
    // Other
    public var id = UUID()
    public var imageData: Data?
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(firstName: String,
                lastName: String,
                phoneNumbers: [PhoneNumber],
                imageData: Data? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.imageData = imageData
    }
    
    //==================================================//
    
    /* MARK: - Hashing Methods */
    
    public func hashSerialized() -> [String] {
        var hashFactors = [String]()
        
        hashFactors.append(contentsOf: phoneNumbers.digits)
        hashFactors.append(contentsOf: phoneNumbers.labels)
        
        // Add image data
        
        return hashFactors
    }
    
    //==================================================//
    
    /* MARK: - Equatable Compliance Method */
    
    public static func == (left: Contact, right: Contact) -> Bool {
        let namesMatch = "\(left.firstName) \(left.lastName)" == "\(right.firstName) \(right.lastName)"
        let phoneNumbersMatch = left.phoneNumbers.digits == right.phoneNumbers.digits
        let hashesMatch = left.hash == right.hash
        let imageDataMatch = left.imageData == right.imageData
        
        return namesMatch && phoneNumbersMatch && hashesMatch && imageDataMatch
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == CNLabeledValue<CNPhoneNumber> {
    func asPhoneNumbers() -> [PhoneNumber] {
        var phoneNumbers = [PhoneNumber]()
        
        for number in self {
            var localizedLabel: String?
            if let label = number.label {
                localizedLabel = CNLabeledValue<NSString>.localizedString(forLabel: label)
            }
            
            var callingCode: String?
            if let countryCode = number.value.value(forKey: "countryCode") as? String {
                callingCode = RegionDetailServer.getCallingCode(forRegion: countryCode)
            }
            
            let phoneNumber = PhoneNumber(digits: number.value.stringValue.digits,
                                          rawStringHasPlusPrefix: number.value.stringValue.hasPrefix("+"),
                                          label: localizedLabel,
                                          formattedString: number.value.value(forKey: "formattedInternationalStringValue") as? String,
                                          callingCode: callingCode)
            
            phoneNumbers.append(phoneNumber)
        }
        
        return phoneNumbers
    }
}

public extension Array where Element == Contact {
    /* MARK: - Methods */
    
    func hashes() -> [String] {
        var hashes = [String]()
        
        for contact in self {
            hashes.append(contact.hash)
        }
        
        return hashes
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var sorted: [[Any]] {
        var contactsToReturn = [ContactPair]()
        var contactsToFetch = [Contact]()
        
        for contact in self {
            guard let retrievedContact = ContactArchiver.getFromArchive(contact.hash) else {
                contactsToFetch.append(contact)
                continue
            }
            
            contactsToReturn.append(retrievedContact)
        }
        
        return [contactsToReturn, contactsToFetch]
    }
}

public extension Array where Element == String {
    func hashes() -> [String] {
        var hashes = [String]()
        
        for item in self {
            hashes.append(item.compressedHash)
        }
        
        return hashes
    }
}

/* MARK: Contact */
public extension Contact {
    
    /* MARK: - Methods */
    
    static func empty() -> Contact {
        return Contact(firstName: "",
                       lastName: "",
                       phoneNumbers: [])
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var hash: String {
        do {
            let encoder = JSONEncoder()
            let encodedContact = try! encoder.encode(self.hashSerialized())
            
            return encodedContact.compressedHash
        }
    }
}
