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
    
    /* MARK: - Constructor Method */
    
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
