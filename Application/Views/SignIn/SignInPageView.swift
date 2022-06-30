//
//  SignInPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import PhoneNumberKit

//==================================================//

/* MARK: - Views */

public struct SignInPageView: View {
    @StateObject public var viewModel: SignInPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @State private var phoneNumberString: String = callingCode
    @State private var verificationCode: String = ""
    
    @State private var verificationIdentifier: String = "" {
        didSet {
            verified = true
        }
    }
    
    @State private var verified = false
    
    //==================================================//
    
    /* MARK: - Views */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("Loading...")
        case .loaded(let translations):
            Spacer()
            
            VStack(alignment: .center) {
                Image(uiImage: UIImage(named: "Hello.png")!)
                    .resizable()
                    .frame(width: 150, height: 70)
                    .padding(.bottom, 30)
                
                if verified {
                    Text(translations["codePrompt"]!.output)
                        .bold()
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                        .padding(.vertical, 5)
                    
                    TextField("000000", text: $verificationCode)
                        .padding(.vertical, 2)
                        .multilineTextAlignment(.center)
                        .overlay(Rectangle()
                                    .stroke(lineWidth: 1))
                        .padding(.horizontal, 30)
                        .keyboardType(.numberPad)
                } else {
                    Text(translations["phoneNumberPrompt"]!.output)
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
                                phoneNumberString = "+\(formatted)".replacingOccurrences(of: "(", with: " (").replacingOccurrences(of: "+ (", with: "+(")
                            }
                        })
                }
                
                Button {
                    if verified {
                        viewModel.authenticateUser(identifier: verificationIdentifier,
                                                   verificationCode: verificationCode) { (userID, returnedError) in
                            if let identifier = userID {
                                currentUserID = identifier
                                viewRouter.currentPage = .home
                            } else if let error = returnedError {
                                log(errorInfo(error),
                                    metadata: [#file, #function, #line])
                                
                                let akError = AKError(errorInfo(error),
                                                      metadata: [#file, #function, #line],
                                                      isReportable: false)
                                AKErrorAlert(message: viewModel.simpleErrorString(error.localizedDescription),
                                             error: akError).present()
                                
                            }
                        }
                    } else {
                        viewModel.verifyPhoneNumber(phoneNumberString) { (returnedIdentifier,
                                                                          returnedError) in
                            if let identifier = returnedIdentifier {
                                guard phoneNumberString.digitalValue != nil else {
                                    print("phone number not int")
                                    return
                                }
                                
                                verificationIdentifier = identifier
                            } else if let error = returnedError {
                                let akError = AKError(errorInfo(error),
                                                      metadata: [#file, #function, #line],
                                                      isReportable: false)
                                AKErrorAlert(message: viewModel.simpleErrorString(errorInfo(error)),
                                             error: akError,
                                             networkDependent: true).present()
                            }
                        }
                    }
                } label: {
                    Text(verified ? translations["finish"]!.output : translations["continue"]!.output)
                        .bold()
                }
                .padding(.top, 5)
                .accentColor(.blue)
                .disabled(verified ? verificationCode.lowercasedTrimmingWhitespace.count != 6 : phoneNumberString.removingOccurrences(of: ["+"]).lowercasedTrimmingWhitespace.count < 7)
                
                Button {
                    if verified {
                        verified = false
                    } else {
                        viewRouter.currentPage = .main
                    }
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
