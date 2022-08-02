//
//  ContactInfo.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import ContactsUI

public struct ContactInfo: Identifiable {
    public var id = UUID()
    
    public var firstName: String
    public var lastName: String
    
    public var phoneNumber: CNPhoneNumber?
}
