//
//  PhoneNumberPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import Firebase
import PhoneNumberKit

public struct PhoneNumberPageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    @StateObject public var viewModel: PhoneNumberPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @State private var errored = false
    @State private var errorDescriptor = "" {
        didSet {
            errored = true
        }
    }
    
    @State private var phoneNumberString: String = callingCode
    
    //==================================================//
    
    /* MARK: - Views */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("Loading...")
        case .loaded(let translations):
            TitleSubtitleView(translations: translations)
            
            Spacer()
            
            VStack(alignment: .center) {
                Text(translations["instruction"]!.output)
                    .bold()
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                    .padding(.vertical, 5)
                
                TextField("+1 (555) 555-5555", text: $phoneNumberString)
                    //                    .textFieldStyle(.plain)
                    .padding(.vertical, 2)
                    .multilineTextAlignment(.center)
                    .overlay(Rectangle()
                                .stroke(lineWidth: 1))
                    .keyboardType(.phonePad)
                    .padding(.horizontal, 30)
                    .onChange(of: phoneNumberString, perform: { value in
                        DispatchQueue.main.async {
                            guard let digits = phoneNumberString.digitalValue else {
                                phoneNumberString = "+"
                                return
                            }
                            
                            let formatted = PartialFormatter().formatPartial("\(digits)")
                            print(formatted)
                            phoneNumberString = "+\(formatted)".replacingOccurrences(of: "(", with: " (").replacingOccurrences(of: "+ (", with: "+(")
                        }
                    })
                
                Button {
                    viewModel.verifyPhoneNumber(phoneNumberString) { (returnedIdentifier,
                                                                      returnedError) in
                        if let identifier = returnedIdentifier {
                            guard let phoneNumber = phoneNumberString.digitalValue else {
                                print("phone number not int")
                                return
                            }
                            
                            viewRouter.currentPage = .signUp_verifyPhoneNumber(identifier: identifier,
                                                                               phoneNumber: phoneNumber)
                        } else if let error = returnedError {
                            errorDescriptor = (error as NSError).localizedDescription
                        }
                    }
                } label: {
                    Text(translations["continue"]!.output)
                        .bold()
                }
                .padding(.top, 5)
                .accentColor(.blue)
                .disabled(phoneNumberString.removingOccurrences(of: ["+"]).lowercasedTrimmingWhitespace.count < 7)
                .alert(isPresented: $errored) {
                    return Alert(title: Text(viewModel.getErrorAlertText(errorDescriptor)))
                }
                
                Button {
                    viewRouter.currentPage = .main
                } label: {
                    Text(translations["back"]!.output)
                }
                .padding(.top, 2)
                .foregroundColor(.blue)
                .font(.system(size: 15))
            }
            .padding(.bottom, 30)
            
            Spacer()
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}
