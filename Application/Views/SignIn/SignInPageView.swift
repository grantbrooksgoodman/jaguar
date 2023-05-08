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
import Firebase
import FirebaseAuth
import PhoneNumberKit

public struct SignInPageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Other
    @StateObject public var viewModel: SignInPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    // Booleans
    @State private var pressedContinue = false
    @State private var verified = false
    
    // Strings
    @State public var phoneNumberString: String
    @State public var fromSignUp: Bool
    
    @State private var verificationIdentifier: String = "" {
        didSet {
            verified = true
        }
    }
    @State private var verificationCode: String = ""
    @State private var selectedRegion = "US"
    
    @Environment(\.colorScheme) private var colorScheme
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear {
                Core.restoreDeviceLanguageCode()
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
                        .renderingMode(colorScheme == .dark ? .template : .original)
                        .foregroundColor(colorScheme == .dark ? Color(uiColor: UIColor(hex: 0xF8F8F8)) : .none)
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
                            RegionMenu(selectedRegionCode: $selectedRegion)
                                .padding(.leading, 20)
                                .padding(.trailing, 5)
                            
                            PhoneNumberTextField(phoneNumberString: $phoneNumberString,
                                                 region: selectedRegion)
                            .padding(.vertical, 2)
                            .padding(.trailing, 20)
                        }
                    }
                    
                    Button {
                        pressedContinue = true
                        
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
                    .disabled(pressedContinue)
                    
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
            FailureView(exception: exception) { viewModel.load() }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func authenticateUser() {
        viewModel.authenticateUser(identifier: verificationIdentifier,
                                   verificationCode: verificationCode) { (userID, returnedError) in
            guard let identifier = userID else {
                let error = returnedError == nil ? Exception(metadata: [#file, #function, #line]) : Exception(returnedError!, metadata: [#file, #function, #line])
                Logger.log(error, with: .errorAlert)
                self.pressedContinue = false
                return
            }
            
            RuntimeStorage.store(identifier, as: .currentUserID)
            viewRouter.currentPage = .conversations
            AnalyticsService.logEvent(.logIn)
            // self.pressedContinue = false
        }
    }
    
    private func verifyPhoneNumber() {
        let compiledNumber = "\(RuntimeStorage.callingCodeDictionary![selectedRegion]!)\(phoneNumberString.digits)"
        let phoneNumber = PhoneNumber(digits: compiledNumber.digits,
                                      rawStringHasPlusPrefix: true,
                                      formattedString: phoneNumberString,
                                      callingCode: RuntimeStorage.callingCodeDictionary![selectedRegion]!)
        
        PhoneNumberService.verifyUser(phoneNumber: phoneNumber) { _, exception, hasAccount in
            guard hasAccount else {
                let alert = AKAlert(message: "There is no account registered with this phone number. Please sign up instead.", actions: [AKAction(title: "Sign Up", style: .preferred)])
                
                alert.present() { actionID in
                    guard actionID == -1 else {
                        RuntimeStorage.store(phoneNumberString, as: .numberFromSignIn)
                        viewRouter.currentPage = .signUp_selectLanguage
                        self.pressedContinue = false
                        return
                    }
                    
                    self.pressedContinue = false
                }
                
                return
            }
            
            Auth.auth().languageCode = RuntimeStorage.languageCode!
            PhoneAuthProvider.provider().verifyPhoneNumber("+\(compiledNumber.digits)",
                                                           uiDelegate: nil) { (identifier,
                                                                               error) in
                guard let identifier else {
                    let exception = error == nil ? Exception(metadata: [#file, #function, #line]) : Exception(error!, metadata: [#file, #function, #line])
                    Logger.log(exception, with: .errorAlert)
                    self.pressedContinue = false
                    return
                }
                
                verificationIdentifier = identifier
                RuntimeStorage.remove(.selectedRegionCode)
                self.pressedContinue = false
            }
        }
    }
}
