//
//  VerifyNumberPageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

/* Third-party Frameworks */
import AlertKit
import Firebase
import PhoneNumberKit

/**
 Verifies the user's phone number through `PhoneAuthProvider`.
 */
public struct VerifyNumberPageView: View {
    
    //==================================================//
    
    /* MARK: - Struct-level Variable Declarations */
    
    //Strings
    @State private var phoneNumberString: String = ""
    @State private var selectedRegion = "US"
    
    //Other Declarations
    @StateObject public var viewModel: VerifyNumberPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
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
                
                HStack(alignment: .center) {
                    RegionMenu(selectedRegion: $selectedRegion)
                        .padding(.leading, 20)
                        .padding(.trailing, 5)
                    
                    PhoneNumberTextField(phoneNumberString: $phoneNumberString,
                                         region: selectedRegion)
                        .padding(.vertical, 2)
                        .padding(.trailing, 20)
                }
                
                Button {
                    let compiledNumber = "\(callingCodeDictionary[selectedRegion]!)\(phoneNumberString.digits)".digits
                    
                    selectedRegionCode = selectedRegion
                    verifyUser(phoneNumber: compiledNumber)
                } label: {
                    Text(translations["continue"]!.output)
                        .bold()
                }
                .padding(.top, 5)
                .accentColor(.blue)
                .disabled(phoneNumberString.removingOccurrences(of: ["+"]).lowercasedTrimmingWhitespace.count < 7)
                
                Button {
                    viewRouter.currentPage = .signUp_selectLanguage
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
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func verifyUser(phoneNumber: String) {
        viewModel.verifyUser(phoneNumber: phoneNumber) { (returnedIdentifier,
                                                          errorDescriptor,
                                                          hasAccount) in
            guard !hasAccount else {
                let alert = AKAlert(message: "It appears you already have an account. Please sign in instead.", actions: [AKAction(title: "Sign In", style: .preferred)])
                
                alert.present() { actionID in
                    guard actionID == -1 else {
                        viewRouter.currentPage = .signIn(phoneNumber: phoneNumberString.digits.formattedPhoneNumber(region: selectedRegion),
                                                         fromSignUp: true)
                        return
                    }
                    
                    languageCode = previousLanguageCode
                }
                
                return
            }
            
            guard let identifier = returnedIdentifier else {
                let akError = AKError(errorDescriptor ?? "An unknown error occurred.",
                                      metadata: [#file, #function, #line],
                                      isReportable: true)
                
                AKErrorAlert(error: akError,
                             networkDependent: true).present()
                return
            }
            
            viewRouter.currentPage = .signUp_authCode(identifier: identifier,
                                                      phoneNumber: phoneNumber,
                                                      region: selectedRegionCode ?? selectedRegion)
            selectedRegionCode = nil
        }
    }
}
