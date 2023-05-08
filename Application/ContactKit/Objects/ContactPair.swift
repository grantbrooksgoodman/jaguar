//
//  ContactPair.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 02/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct ContactPair: Codable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var contact: Contact!
    public var numberPairs: [NumberPair]?
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(contact: Contact, numberPairs: [NumberPair]?) {
        self.contact = contact
        self.numberPairs = numberPairs
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: Array */
public extension Array where Element == ContactPair {
    var contacts: [Contact] {
        var contactArray = [Contact]()
        
        for item in self {
            contactArray.append(item.contact)
        }
        
        return contactArray
    }
    
    var uniquePairs: [ContactPair] {
        var uniquePairs = [ContactPair]()
        
        for pair in self {
            if !uniquePairs.contains(where: { ($0.contact.firstName == pair.contact.firstName) &&
                ($0.contact.lastName == pair.contact.lastName) }) {
                uniquePairs.append(pair)
            }
        }
        
        return uniquePairs
    }
}

/* MARK: ContactPair */
public extension ContactPair {
    /* MARK: - Functions */
    
    //    static func == (left: ContactPair, right: ContactPair) -> Bool {
    //        let contactsMatch = left.contact == right.contact
    //        var usersMatch = left.users == nil && right.users == nil
    //
    //        if let leftUsers = left.users,
    //           let rightUsers = right.users {
    //            usersMatch = leftUsers.identifiers() == rightUsers.identifiers()
    //        }
    //
    //        return contactsMatch && usersMatch
    //    }
}

/* MARK: ContactPair */
public extension ContactPair {
    var isEmpty: Bool {
        guard numberPairs == nil else {
            guard numberPairs!.isEmpty else { return false }
            return true
        }
        
        guard contact.firstName == "",
              contact.lastName == "",
              contact.phoneNumbers.isEmpty else { return false }
        
        return true
    }
}
