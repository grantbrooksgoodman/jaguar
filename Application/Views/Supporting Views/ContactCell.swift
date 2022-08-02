//
//  ContactCell.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 22/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct ContactCell: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    public var contact: ContactInfo
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        Text("\(contact.firstName) \(contact.lastName)")
            .foregroundColor(.primary)
    }
}
