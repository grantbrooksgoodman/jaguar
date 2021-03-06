//
//  PhoneNumberTextField.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 09/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

/* Third-party Frameworks */
import PhoneNumberKit

public struct PhoneNumberTextField: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Strings
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
            .onChange(of: phoneNumberString, perform: { _ in
                DispatchQueue.main.async {
                    phoneNumberString = phoneNumberString.formattedPhoneNumber(region: region)
                }
            })
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func placeholderText() -> String {
        let phoneNumberKit = PhoneNumberKit()
        
        if let regionMetadata = phoneNumberKit.metadata(for: region),
           let description = regionMetadata.mobile,
           let exampleNumber = description.exampleNumber {
            return exampleNumber.formattedPhoneNumber(region: region)
        }
        
        return "(555) 555-5555"
    }
}
