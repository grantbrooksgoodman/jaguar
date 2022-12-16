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
            if !uniquePairs.contains(where: { $0 == pair }) {
                uniquePairs.append(pair)
            }
        }
        
        return uniquePairs
    }
}

/* MARK: ContactPair */
public extension ContactPair {
    /* MARK: - Functions */
    
    static func == (left: ContactPair, right: ContactPair) -> Bool {
        let contactsMatch = left.contact == right.contact
        var usersMatch = left.users == nil && right.users == nil
        
        if let leftUsers = left.users,
           let rightUsers = right.users {
            usersMatch = leftUsers.identifiers() == rightUsers.identifiers()
        }
        
        return contactsMatch && usersMatch
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
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var isEmpty: Bool {
        let contactIsEmpty = contact.firstName.isEmpty && contact.lastName.isEmpty && contact.phoneNumbers.isEmpty
        return contactIsEmpty && users == nil
    }
}
