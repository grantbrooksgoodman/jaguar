//
//  AuthCodePageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit

/**
 Authenticates and signs the user in;
 generates Firebase UID.
 */
public struct AuthCodePageView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // Other
    @StateObject public var viewModel: AuthCodePageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    // Strings
    @State public var phoneNumber: String
    @State public var region: String
    @State public var verificationIdentifier: String
    
    @State private var verificationCode: String = ""
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            VStack {
                TitleSubtitleView(translations: translations)
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text(translations["instruction"]!.output)
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
                    
                    Button {
                        viewModel.authenticateUser(identifier: verificationIdentifier,
                                                   verificationCode: verificationCode) { (userID, returnedError) in
                            if let identifier = userID {
                                let callingCode = RegionDetailServer.getCallingCode(forRegion: region)
                                
                                UserSerializer.shared.createUser(identifier,
                                                                 callingCode: callingCode ?? "1",
                                                                 languageCode: RuntimeStorage.languageCode!,
                                                                 phoneNumber: phoneNumber,
                                                                 region: region) { (errorDescriptor) in
                                    guard errorDescriptor == nil else {
                                        Logger.log(errorDescriptor ?? "An unknown error occurred.",
                                                   with: .errorAlert,
                                                   metadata: [#file, #function, #line])
                                        return
                                    }
                                    
                                    AKAlert(message: "Account created successfully.",
                                            cancelButtonTitle: "OK").present()
                                }
                            } else if let error = returnedError {
                                Logger.log(error,
                                           with: .errorAlert,
                                           metadata: [#file, #function, #line])
                                
                            }
                        }
                    } label: {
                        Text(translations["finish"]!.output)
                            .bold()
                    }
                    .padding(.top, 5)
                    .accentColor(.blue)
                    .disabled(verificationCode.lowercasedTrimmingWhitespace.count != 6)
                    
                    Button {
                        viewRouter.currentPage = .signUp_verifyNumber
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
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}
