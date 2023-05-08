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
    
    /* MARK: - Properties */
    
    // Strings
    @State private var phoneNumberString: String = RuntimeStorage.numberFromSignIn ?? ""
    @State private var selectedRegion = RuntimeStorage.selectedRegionCode ?? "US"
    
    // Other
    @StateObject public var viewModel: VerifyNumberPageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    @State private var pressedContinue = false
    
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
                    
                    HStack(alignment: .center) {
                        RegionMenu(selectedRegionCode: $selectedRegion)
                            .padding(.leading, 20)
                            .padding(.trailing, 5)
                        
                        PhoneNumberTextField(phoneNumberString: $phoneNumberString,
                                             region: selectedRegion)
                        .padding(.vertical, 2)
                        .padding(.trailing, 20)
                    }
                    
                    Button {
                        pressedContinue = true
                        
                        RuntimeStorage.store(selectedRegion, as: .selectedRegionCode)
                        let callingCode = RegionDetailServer.getCallingCode(forRegion: selectedRegion)
                        let compiledNumber = "\(RuntimeStorage.callingCodeDictionary![selectedRegion]!)\(phoneNumberString.digits)"
                        
                        let phoneNumber = PhoneNumber(digits: compiledNumber.digits,
                                                      rawStringHasPlusPrefix: true,
                                                      formattedString: phoneNumberString,
                                                      callingCode: callingCode!)
                        verifyUser(phoneNumber: phoneNumber)
                    } label: {
                        Text(translations["continue"]!.output)
                            .bold()
                    }
                    .padding(.top, 5)
                    .accentColor(.blue)
                    .disabled(phoneNumberString.removingOccurrences(of: ["+"]).lowercasedTrimmingWhitespace.count < 7)
                    .disabled(pressedContinue)
                    
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
            }
            .onAppear { RuntimeStorage.store(#file, as: .currentFile) }
        case .failed(let exception):
            FailureView(exception: exception) { viewModel.load() }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    private func verifyUser(phoneNumber: PhoneNumber) {
        PhoneNumberService.verifyUser(phoneNumber: phoneNumber) { (identifier,
                                                                   exception,
                                                                   hasAccount) in
            guard !hasAccount else {
                let alert = AKAlert(message: "It appears you already have an account. Please sign in instead.", actions: [AKAction(title: "Sign In", style: .preferred)])
                
                alert.present() { actionID in
                    guard actionID == -1 else {
                        viewRouter.currentPage = .signIn(phoneNumber: phoneNumberString.partiallyFormatted(for: selectedRegion))
                        self.pressedContinue = false
                        return
                    }
                    
                    self.pressedContinue = false
                }
                
                return
            }
            
            guard let identifier else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]),
                           with: .errorAlert)
                self.pressedContinue = false
                return
            }
            
            viewRouter.currentPage = .signUp_authCode(identifier: identifier,
                                                      phoneNumber: phoneNumberString.digits,
                                                      region: RuntimeStorage.selectedRegionCode ?? selectedRegion)
            RuntimeStorage.remove(.selectedRegionCode)
            self.pressedContinue = false
        }
    }
}
