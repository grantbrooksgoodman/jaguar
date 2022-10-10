//
//  ContactPair.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 02/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public struct ContactPair: Codable, Equatable {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var contact: Contact!
    public var users: [User]?
    
    //==================================================//
    
    /* MARK: - Constructor Function */
    
    public init(contact: Contact, users: [User]?) {
        self.contact = contact
        self.users = users
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
            if !uniquePairs.contains(where: { $0.contact.hash == pair.contact.hash }) {
                uniquePairs.append(pair)
            }
        }
        
        return uniquePairs
    }
}

/* MARK: ContactPair */
public extension ContactPair {
    static func == (left: ContactPair, right: ContactPair) -> Bool {
#warning("This is incomplete.")
        if left.contact.hash == right.contact.hash {
            return true
        }
        
        return false
    }
    
    func exactMatches(withUsers: [User]) -> [User] {
        var users = [User]()
        
        for user in withUsers {
            for number in contact.phoneNumbers {
                let exactMatch = "\(user.callingCode!)\(user.phoneNumber!)".digits == number.digits
                
                if exactMatch {
                    users.append(user)
                }
            }
        }
        
        return users
    }
}
