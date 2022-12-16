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
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(firstName: String,
                lastName: String,
                phoneNumbers: [PhoneNumber]) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
    }
    
    //==================================================//
    
    /* MARK: - Hashing Functions */
    
    public func hashSerialized() -> [String] {
        var hashFactors = [String]()
        
        hashFactors.append(contentsOf: phoneNumbers.digits)
        hashFactors.append(contentsOf: phoneNumbers.labels)
        
        return hashFactors
    }
    
    //==================================================//
    
    /* MARK: - Equatable Compliance Function */
    
    public static func == (left: Contact, right: Contact) -> Bool {
        let namesMatch = "\(left.firstName) \(left.lastName)" == "\(right.firstName) \(right.lastName)"
        let phoneNumbersMatch = left.phoneNumbers.digits == right.phoneNumbers.digits
        let hashesMatch = left.hash == right.hash
        
        return namesMatch && phoneNumbersMatch && hashesMatch
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
            
            let phoneNumber = PhoneNumber(digits: number.value.stringValue.digits,
                                          label: localizedLabel)
            
            phoneNumbers.append(phoneNumber)
        }
        
        return phoneNumbers
    }
}

public extension Array where Element == Contact {
    /* MARK: - Functions */
    
    func asBlankContactPairs() -> [ContactPair] {
        var contactPairs = [ContactPair]()
        
        for contact in self {
            contactPairs.append(ContactPair(contact: contact,
                                            users: nil))
        }
        
        return contactPairs
    }
    
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
    var hash: String {
        do {
            let encoder = JSONEncoder()
            let encodedContact = try! encoder.encode(self.hashSerialized())
            
            return encodedContact.compressedHash
        }
    }
}
