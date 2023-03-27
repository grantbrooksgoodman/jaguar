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
    
    @State private var pressedContinue = false
    
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
                        .overlay(VStack {
                            Divider()
                                .offset(x: 0, y: 15)
                        })
                        .padding(.horizontal, 30)
                        .keyboardType(.numberPad)
                    
                    Button {
                        pressedContinue = true
                        authenticateUser()
                    } label: {
                        Text(translations["continue"]!.output)
                            .bold()
                    }
                    .padding(.top, 5)
                    .accentColor(.blue)
                    .disabled(verificationCode.lowercasedTrimmingWhitespace.count != 6)
                    .disabled(pressedContinue)
                    
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
            }
            .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
        case .failed(let exception):
            FailureView(exception: exception) { viewModel.load() }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func authenticateUser() {
        viewModel.authenticateUser(identifier: verificationIdentifier,
                                   verificationCode: verificationCode) { userID, returnedError in
            guard let userID else {
                if let returnedError {
                    Logger.log(Exception(returnedError, metadata: [#file, #function, #line]),
                               with: .errorAlert)
                } else {
                    Logger.log(Exception(metadata: [#file, #function, #line]),
                               with: .errorAlert)
                }
                
                self.pressedContinue = false
                
                return
            }
            
            viewRouter.currentPage = .signUp_permissions(phoneNumber: phoneNumber,
                                                         region: region,
                                                         userID: userID)
            self.pressedContinue = false
        }
    }
}
