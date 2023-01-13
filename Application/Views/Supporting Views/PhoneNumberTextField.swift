//
//  PhoneNumberTextField.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 09/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import PhoneNumberKit

public struct PhoneNumberTextField: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Strings
    @Binding public var phoneNumberString: String
    public var region: String
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        TextField(placeholderText(),
                  text: $phoneNumberString)
        .multilineTextAlignment(.center)
        .overlay(VStack {
            Divider()
                .offset(x: 0, y: 15)
        })
        .keyboardType(.phonePad)
        .onChange(of: region, perform: { newValue in
            DispatchQueue.main.async {
                phoneNumberString = phoneNumberString.partiallyFormatted(for: newValue)
            }
        })
        .onChange(of: phoneNumberString, perform: { _ in
            DispatchQueue.main.async {
                phoneNumberString = phoneNumberString.partiallyFormatted(for: region)
            }
        })
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func placeholderText() -> String {
        guard region != "US" else {
            return "(555) 555-5555"
        }
        
        let phoneNumberKit = PhoneNumberKit()
        
        if let regionMetadata = phoneNumberKit.metadata(for: region),
           let description = regionMetadata.mobile,
           let exampleNumber = description.exampleNumber {
            return exampleNumber.partiallyFormatted(for: region)
        }
        
        return "(555) 555-5555"
    }
}
