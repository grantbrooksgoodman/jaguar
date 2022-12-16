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
import AlertKit
import PhoneNumberKit

public struct SignInPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @StateObject public var viewModel: SignInPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    // Strings
    @State public var phoneNumberString: String
    @State public var fromSignUp: Bool
    @State private var verificationIdentifier: String = "" {
        didSet {
            verified = true
        }
    }
    @State private var verificationCode: String = ""
    
    // Other
    @State private var verified = false
    @State private var selectedRegion = "US"
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear {
                RuntimeStorage.store(Locale.preferredLanguages[0].components(separatedBy: "-")[0],
                                     as: .languageCode)
                AKCore.shared.setLanguageCode(Locale.preferredLanguages[0].components(separatedBy: "-")[0])
                viewModel.load()
            }
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            VStack {
                Spacer()
                
                VStack(alignment: .center) {
                    Image(uiImage: UIImage(named: "Hello.png")!)
                        .resizable()
                        .frame(width: 150, height: 70)
                        .padding(.bottom, 30)
                    
                    Text(translations[verified ? "codePrompt" : "phoneNumberPrompt"]!.output)
                        .bold()
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                        .padding(.vertical, 5)
                    
                    if verified {
                        TextField("000000", text: $verificationCode)
                            .padding(.vertical, 2)
                            .multilineTextAlignment(.center)
                            .overlay(VStack {
                                Divider()
                                    .offset(x: 0, y: 15)
                            })
                            .padding(.horizontal, 30)
                            .keyboardType(.numberPad)
                    } else {
                        HStack(alignment: .center) {
                            RegionMenu(selectedRegion: $selectedRegion)
                                .padding(.leading, 20)
                                .padding(.trailing, 5)
                            
                            PhoneNumberTextField(phoneNumberString: $phoneNumberString,
                                                 region: selectedRegion)
                            .padding(.vertical, 2)
                            .padding(.trailing, 20)
                        }
                    }
                    
                    Button {
                        if verified {
                            authenticateUser()
                        } else {
                            RuntimeStorage.store(selectedRegion, as: .selectedRegionCode)
                            verifyPhoneNumber()
                        }
                    } label: {
                        Text(translations[verified ? "finish" : "continue"]!.output)
                            .bold()
                    }
                    .padding(.top, 5)
                    .accentColor(.blue)
                    .disabled(verified ? verificationCode.lowercasedTrimmingWhitespace.count != 6 : phoneNumberString.removingOccurrences(of: ["+"]).lowercasedTrimmingWhitespace.count < 7)
                    
                    Button {
                        if verified {
                            verified = false
                        } else if fromSignUp {
                            viewRouter.currentPage = .signUp_verifyNumber
                        } else {
                            viewRouter.currentPage = .initial
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
            }.onAppear { RuntimeStorage.store(#file, as: .currentFile) }
        case .failed(let exception):
            Text(exception.userFacingDescriptor)
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func authenticateUser() {
        viewModel.authenticateUser(identifier: verificationIdentifier,
                                   verificationCode: verificationCode) { (userID, returnedError) in
            guard let identifier = userID else {
                let error = returnedError == nil ? Exception(metadata: [#file, #function, #line]) : Exception(returnedError!,
                                                                                                              metadata: [#file, #function, #line])
                Logger.log(error,
                           with: .errorAlert)
                return
            }
            
            RuntimeStorage.store(identifier, as: .currentUserID)
            viewRouter.currentPage = .conversations
        }
    }
    
    private func verifyPhoneNumber() {
        let compiledNumber = "\(RuntimeStorage.callingCodeDictionary![selectedRegion]!)\(phoneNumberString.digits)".digits
        
        viewModel.verifyPhoneNumber("+\(compiledNumber)") { (returnedIdentifier,
                                                             returnedError) in
            
            guard let identifier = returnedIdentifier else {
                let error = returnedError == nil ? Exception(metadata: [#file, #function, #line]) : Exception(returnedError!,
                                                                                                              metadata: [#file, #function, #line])
                Logger.log(error,
                           with: .errorAlert)
                return
            }
            
            verificationIdentifier = identifier
            RuntimeStorage.remove(.selectedRegionCode)
        }
    }
}
