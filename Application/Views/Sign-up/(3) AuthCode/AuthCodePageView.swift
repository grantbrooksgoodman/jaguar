//
//  AuthCodePageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 01/05/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

/**
 Authenticates and signs the user in;
 generates Firebase UID.
 */
public struct AuthCodePageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    @StateObject public var viewModel: AuthCodePageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    //Strings
    @State public var verificationIdentifier: String
    
    @State private var errorDescriptor = ""
    @State public var phoneNumber: String
    @State public var region: String
    @State private var verificationCode: String = ""
    
    //Other Declarations
    @State private var errored = false
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("" /*"Loading..."*/)
        case .loaded(let translations):
            TitleSubtitleView(translations: translations)
            
            Spacer()
            
            VStack(alignment: .center) {
                Text(translations["instruction"]!.output)
                    .bold()
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                    .padding(.vertical, 5)
                
                TextField("000000", text: $verificationCode)
                    //                    .textFieldStyle(.plain)
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
                            UserSerializer.shared.createUser(identifier,
                                                             languageCode: languageCode,
                                                             phoneNumber: phoneNumber,
                                                             region: region) { (errorDescriptor) in
                                if let error = errorDescriptor {
                                    print(error)
                                } else {
                                    AKAlert(message: "Account created successfully.",
                                            cancelButtonTitle: "OK").present()
                                }
                            }
                            
                        } else if let error = returnedError {
                            errored = true
                            errorDescriptor = (error as NSError).localizedDescription
                            Logger.log(Logger.errorInfo(error),
                                       metadata: [#file, #function, #line])
                            let error = AKError(Logger.errorInfo(error),
                                                metadata: [#file, #function, #line],
                                                isReportable: false)
                            AKErrorAlert(message: viewModel.simpleErrorString(errorDescriptor),
                                         error: error).present()
                            
                        }
                    }
                } label: {
                    Text(translations["finish"]!.output)
                        .bold()
                }
                .padding(.top, 5)
                .accentColor(.blue)
                .disabled(verificationCode.lowercasedTrimmingWhitespace.count != 6)
                //                .alert(isPresented: $errored) {
                //                    return Alert(title: Text(viewModel.simpleErrorString(errorDescriptor)))
                //                }
                
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
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}
